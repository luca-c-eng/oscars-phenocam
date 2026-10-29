#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# config_read.sh — reads settings.txt (positional format) and exports
# all configuration variables for use by other scripts.

# configure_station_timezone — configure a fixed station timezone from UTC_OFFSET.
#
# PhenoCam station time never applies daylight saving time.
# Examples:
#   UTC_OFFSET=+1  -> fixed UTC+1 all year
#   UTC_OFFSET=-5  -> fixed UTC-5 all year
#   UTC_OFFSET=0   -> UTC
configure_station_timezone() {
  local raw="${UTC_OFFSET:-}"
  local sign offset

  if [[ "$raw" == "0" || "$raw" == "+0" || "$raw" == "-0" ]]; then
    TZ="UTC0"
    TZ_LABEL="UTC+0"
  elif [[ "$raw" =~ ^([+-])([0-9]|1[0-4])(:[0-5][0-9])?$ ]]; then
    sign="${BASH_REMATCH[1]}"
    offset="${BASH_REMATCH[2]}${BASH_REMATCH[3]:-}"

    # POSIX TZ offsets use the opposite sign:
    # UTC-1 means local time UTC+1.
    if [[ "$sign" == "+" ]]; then
      TZ="UTC-${offset}"
    else
      TZ="UTC+${offset}"
    fi

    TZ_LABEL="UTC${raw}"
  else
    return 1
  fi

  export TZ TZ_LABEL
}

read_settings() {
  local f="$1"
  [[ -f "$f" ]] || return 1

  # Read non-empty, non-comment lines only. Strip CR in case file was edited
  # on Windows/macOS tools that introduced CRLF line endings.
  local line
  L=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    L+=("$line")
  done < "$f"

  # Minimum 6 required fields.
  [[ "${#L[@]}" -ge 6 ]] || return 2

  SITENAME="${L[0]}"
  UTC_OFFSET="${L[1]}"
  TZ_LABEL="${L[2]}"
  START_HOUR="${L[3]}"
  END_HOUR="${L[4]}"
  INTERVAL_MIN="${L[5]}"

  # Optional fields (backward compatible — defaults applied if missing):
  IFACE="${L[6]:-auto}"                    # auto | eth0 | wlan0 | other explicit interface
  LEGACY_REMOTE_USER="${L[7]:-}"           # reserved legacy position

  NET_MODE="${L[8]:-auto}"                 # auto | ethernet | wifi
  RAM_MIN_FREE_MB="${L[9]:-20}"            # RAMDISK free-space threshold (MB) before spillover
  SD_MAX_USED_PCT="${L[10]:-80}"           # SD usage threshold (%); captures stop if exceeded
  USB_MOUNT_BASES="${L[11]:-/media:/mnt}"  # colon-separated base paths to scan for USB mounts
  USB_MAX_USED_PCT="${L[12]:-90}"          # USB usage threshold (%); spills to SD if exceeded
  # Field 14 is retained positionally for upgrades, but this development line
  # has one upload backend only.
  REMOTE_LAYOUT="icos"

  SITE_LAT="${L[14]:-nd}"
  SITE_LON="${L[15]:-nd}"
  SITE_ELEV_M="${L[16]:-nd}"
  SITE_START_DATE="${L[17]:-nd}"
  SITE_END_DATE="${L[18]:-nd}"
  SITE_NIMAGE="${L[19]:-nd}"

  # v1.4.0 — hardware configuration fields
  BOARD="${L[20]:-unknown}"                # rpi3b+ | rpizero2w | unknown
  CAMERA_MODEL="${L[21]:-imx708}"          # imx708 | imx708_noir
  CAPTURE_TIMEOUT="${L[22]:-30000}"        # ms; default validated on RPi 3B+ and Zero 2W

  # v1.8.0 — Phenocam Vision Edge integration fields
  VISION_EDGE_ENABLED="${L[23]:-off}"      # on | off
  VISION_EDGE_MODE="${L[24]:-metadata}"    # metadata | annotated | delete
  # Previous development configurations may contain the former Vision Edge
  # blur-action token. The ICOS build never applies that filter and safely
  # migrates the effective action to metadata-only processing.
  if [[ "$VISION_EDGE_MODE" == "privacy" ]]; then
    VISION_EDGE_MODE="metadata"
  fi

  # v0.1.0 — configurable image capture
  IMAGE_WIDTH="${L[25]:-2304}"
  IMAGE_HEIGHT="${L[26]:-1296}"
  IMAGE_QUALITY="${L[27]:-100}"

  # ICOS Carbon Portal integration fields.
  CP_ENVIRONMENT="${L[28]:-staging}"       # staging | production
  CP_SUBMITTER_ID="${L[29]:-nd}"
  CP_STATION_URI="${L[30]:-nd}"
  CP_INSTRUMENT_URI="${L[31]:-nd}"
  ICOS_FILENAME_SUFFIX="${L[32]:-nd}"
  CAPTURE_MINUTE="${L[33]:-0}"             # persistent offset inside INTERVAL_MIN

  # Defensive defaults: never export an invalid capture timeout.
  [[ "$CAPTURE_TIMEOUT" =~ ^[0-9]+$ ]] || CAPTURE_TIMEOUT="30000"

  # Values used in filenames, arithmetic and storage decisions must be safe
  # before any capture or queue operation starts.
  [[ "$SITENAME" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || return 13
  [[ "$START_HOUR" =~ ^([0-9]|1[0-9]|2[0-3])$ ]] || return 14
  [[ "$END_HOUR" =~ ^([1-9]|1[0-9]|2[0-4])$ ]] || return 15
  [[ $((10#$START_HOUR)) -lt $((10#$END_HOUR)) ]] || return 16
  case "$NET_MODE" in
    auto|ethernet|wifi) ;;
    *) return 17 ;;
  esac
  [[ "$RAM_MIN_FREE_MB" =~ ^(0|[1-9][0-9]{0,5})$ ]] || return 18
  [[ "$SD_MAX_USED_PCT" =~ ^([1-9]|[1-9][0-9]|100)$ ]] || return 19
  [[ "$USB_MAX_USED_PCT" =~ ^([1-9]|[1-9][0-9]|100)$ ]] || return 20

  # Camera Module 3 sensor-mode resolutions documented by Raspberry Pi.
  [[ "$IMAGE_WIDTH" =~ ^[1-9][0-9]{0,3}$ ]] || return 4
  [[ "$IMAGE_HEIGHT" =~ ^[1-9][0-9]{0,3}$ ]] || return 5

  case "${IMAGE_WIDTH}x${IMAGE_HEIGHT}" in
    1536x864|2304x1296|4608x2592) ;;
    *) return 6 ;;
  esac

  # rpicam-still JPEG quality range.
  [[ "$IMAGE_QUALITY" =~ ^([1-9]|[1-9][0-9]|100)$ ]] || return 7

  case "$INTERVAL_MIN" in
    5|10|15|20|30|60) ;;
    *) return 8 ;;
  esac
  [[ "$CAPTURE_MINUTE" =~ ^([0-9]|[1-5][0-9])$ ]] || return 9
  [[ $((10#$CAPTURE_MINUTE)) -lt $((10#$INTERVAL_MIN)) ]] || return 10

  case "$CP_ENVIRONMENT" in
    staging|production) ;;
    *) return 11 ;;
  esac
  if [[ "$ICOS_FILENAME_SUFFIX" != "nd" ]]; then
    [[ "$ICOS_FILENAME_SUFFIX" =~ ^[A-Z][A-Z0-9]{1,7}(_[A-Z][A-Z0-9]{1,7})?$ ]] || return 12
  fi

  # Preserve the variable names already consumed by capture and metadata scripts.
  WIDTH="$IMAGE_WIDTH"
  HEIGHT="$IMAGE_HEIGHT"
  QUALITY="$IMAGE_QUALITY"

  # Apply fixed station time. DST is intentionally never used.
  configure_station_timezone || return 3

  export SITENAME UTC_OFFSET TZ_LABEL START_HOUR END_HOUR INTERVAL_MIN
  export IFACE LEGACY_REMOTE_USER NET_MODE RAM_MIN_FREE_MB SD_MAX_USED_PCT
  export USB_MOUNT_BASES USB_MAX_USED_PCT REMOTE_LAYOUT
  export SITE_LAT SITE_LON SITE_ELEV_M SITE_START_DATE SITE_END_DATE SITE_NIMAGE
  export BOARD CAMERA_MODEL CAPTURE_TIMEOUT
  export VISION_EDGE_ENABLED VISION_EDGE_MODE
  export IMAGE_WIDTH IMAGE_HEIGHT IMAGE_QUALITY WIDTH HEIGHT QUALITY
  export CP_ENVIRONMENT CP_SUBMITTER_ID CP_STATION_URI CP_INSTRUMENT_URI
  export ICOS_FILENAME_SUFFIX CAPTURE_MINUTE
}

# validate_vision_edge_settings — reject unsupported detection values.
# Kept separate from read_settings so a detection-only configuration error
# cannot stop capture cycles from continuing to enqueue image/metadata pairs.
validate_vision_edge_settings() {
  case "${VISION_EDGE_ENABLED:-off}" in
    on|off) ;;
    *) return 1 ;;
  esac

  case "${VISION_EDGE_MODE:-metadata}" in
    metadata|annotated|delete) ;;
    *) return 2 ;;
  esac
}

# within_window — returns 0 if current hour is within [START_HOUR, END_HOUR).
within_window() {
  local h_now start_h end_h
  h_now=$((10#$(date +%H)))
  start_h=$((10#${START_HOUR}))
  end_h=$((10#${END_HOUR}))

  [[ "$h_now" -ge "$start_h" && "$h_now" -lt "$end_h" ]]
}
