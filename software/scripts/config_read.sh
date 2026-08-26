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
  mapfile -t L < <(grep -vE '^\s*#' "$f" | sed -e 's/\r$//' -e '/^\s*$/d')

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
  SFTP_USER="${L[7]:-}"                    # SFTP username on the remote server

  NET_MODE="${L[8]:-auto}"                 # auto | ethernet | wifi
  RAM_MIN_FREE_MB="${L[9]:-20}"            # RAMDISK free-space threshold (MB) before spillover
  SD_MAX_USED_PCT="${L[10]:-80}"           # SD usage threshold (%); captures stop if exceeded
  USB_MOUNT_BASES="${L[11]:-/media:/mnt}"  # colon-separated base paths to scan for USB mounts
  USB_MAX_USED_PCT="${L[12]:-90}"          # USB usage threshold (%); spills to SD if exceeded
  REMOTE_LAYOUT="${L[13]:-general}"        # general | icos

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

  # Defensive defaults: never export an invalid capture timeout.
  [[ "$CAPTURE_TIMEOUT" =~ ^[0-9]+$ ]] || CAPTURE_TIMEOUT="30000"

  # Apply fixed station time. DST is intentionally never used.
  configure_station_timezone || return 3

  export SITENAME UTC_OFFSET TZ_LABEL START_HOUR END_HOUR INTERVAL_MIN
  export IFACE SFTP_USER NET_MODE RAM_MIN_FREE_MB SD_MAX_USED_PCT
  export USB_MOUNT_BASES USB_MAX_USED_PCT REMOTE_LAYOUT
  export SITE_LAT SITE_LON SITE_ELEV_M SITE_START_DATE SITE_END_DATE SITE_NIMAGE
  export BOARD CAMERA_MODEL CAPTURE_TIMEOUT
}

# within_window — returns 0 if current hour is within [START_HOUR, END_HOUR).
within_window() {
  local h_now start_h end_h
  h_now=$((10#$(date +%H)))
  start_h=$((10#${START_HOUR}))
  end_h=$((10#${END_HOUR}))

  [[ "$h_now" -ge "$start_h" && "$h_now" -lt "$end_h" ]]
}
