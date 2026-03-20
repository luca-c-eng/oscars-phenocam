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

  export SITENAME UTC_OFFSET TZ_LABEL START_HOUR END_HOUR INTERVAL_MIN
  export IFACE SFTP_USER NET_MODE RAM_MIN_FREE_MB SD_MAX_USED_PCT
  export USB_MOUNT_BASES USB_MAX_USED_PCT
}

# within_window — returns 0 if the current hour is within [START_HOUR, END_HOUR).
# Requires read_settings() to have been called first.
within_window() {
  local h_now
  h_now="$(date +%H)"
  # Simple window: start <= now < end.
  # Note: windows crossing midnight are not yet supported (TBD).
  [[ "$h_now" -ge "$START_HOUR" && "$h_now" -lt "$END_HOUR" ]]
}
