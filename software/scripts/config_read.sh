#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# config_read.sh — reads settings.txt (positional format) and exports
# all configuration variables for use by other scripts.

read_settings() {
  local f="$1"
  [[ -f "$f" ]] || return 1

  # Read non-empty, non-comment lines only.
  mapfile -t L < <(grep -vE '^\s*#' "$f" | sed '/^\s*$/d')

  # Minimum 6 required fields.
  [[ "${#L[@]}" -ge 6 ]] || return 2

  SITENAME="${L[0]}"
  UTC_OFFSET="${L[1]}"
  TZ_LABEL="${L[2]}"
  START_HOUR="${L[3]}"
  END_HOUR="${L[4]}"
  INTERVAL_MIN="${L[5]}"

  # Optional fields (backward compatible — defaults applied if missing):
  IFACE="${L[6]:-}"                        # e.g. eth0, wlan0, usb0 — empty = auto-detect
  SFTP_USER="${L[7]:-}"                    # SFTP username on the remote server

  NET_MODE="${L[8]:-auto}"                 # auto | ethernet | wifi
  RAM_MIN_FREE_MB="${L[9]:-20}"            # RAMDISK free space threshold (MB) before spillover
  SD_MAX_USED_PCT="${L[10]:-80}"           # SD usage threshold (%); captures stop if exceeded
  USB_MOUNT_BASES="${L[11]:-/media:/mnt}"  # colon-separated base paths to scan for USB mounts
  USB_MAX_USED_PCT="${L[12]:-90}"          # USB usage threshold (%); spills to SD if exceeded
  REMOTE_LAYOUT="${L[13]:-general}"        # general | icos

  SITE_LAT="${L[14]:-nd}"                  # decimal degrees, e.g. 41.902782
  SITE_LON="${L[15]:-nd}"                  # decimal degrees, e.g. 12.496366
  SITE_ELEV_M="${L[16]:-nd}"               # metres above sea level, integer
  SITE_START_DATE="${L[17]:-nd}"           # YYYY-MM-DD
  SITE_END_DATE="${L[18]:-nd}"             # YYYY-MM-DD or nd if ongoing
  SITE_NIMAGE="${L[19]:-nd}"               # image count or nd

  # v1.4.0 — hardware configuration fields
  BOARD="${L[20]:-unknown}"                # rpi3b+ | rpizero2w | unknown
                                           # auto-detected and written by install.sh
  CAMERA_MODEL="${L[21]:-imx708}"          # imx708 (Camera Module 3) | imx708_noir (V3 NoIR)

  # Capture timeout: derived from BOARD if not explicitly set.
  # Zero 2W is slower — 30 s is safe on both boards and has no quality impact.
  CAPTURE_TIMEOUT="${L[22]:-30000}"        # ms; default 30000 works on all supported boards

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
