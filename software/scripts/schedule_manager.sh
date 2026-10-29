#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# schedule_manager.sh — creates persistent systemd calendar overrides from
# INTERVAL_MIN and CAPTURE_MINUTE in settings.txt.

schedule_minute_list() {
  local interval="$1" offset="$2" minute
  local -a minutes=()

  for ((minute=offset; minute<60; minute+=interval)); do
    minutes+=("$(printf '%02d' "$minute")")
  done
  local IFS=,
  printf '%s\n' "${minutes[*]}"
}

write_schedule_overrides() {
  local systemd_dir="$1"
  local capture_minutes upload_offset upload_minutes
  local capture_dropin upload_dropin
  local capture_file upload_file capture_tmp upload_tmp

  capture_minutes="$(schedule_minute_list "$INTERVAL_MIN" "$CAPTURE_MINUTE")"
  upload_offset=$(( (10#$CAPTURE_MINUTE + 1) % 10#$INTERVAL_MIN ))
  upload_minutes="$(schedule_minute_list "$INTERVAL_MIN" "$upload_offset")"
  capture_dropin="${systemd_dir}/phenocam-capture.timer.d"
  upload_dropin="${systemd_dir}/phenocam-upload.timer.d"
  capture_file="${capture_dropin}/schedule.conf"
  upload_file="${upload_dropin}/schedule.conf"
  capture_tmp="${capture_file}.tmp"
  upload_tmp="${upload_file}.tmp"

  mkdir -p "$capture_dropin" "$upload_dropin"
  {
    echo '[Timer]'
    echo 'OnCalendar='
    echo "OnCalendar=*-*-* *:${capture_minutes}:00 UTC"
    # Do not create an off-schedule catch-up image after downtime. Persistence
    # refers to the stored minute offset, not to replaying missed timer events.
    echo 'Persistent=false'
    echo 'AccuracySec=1s'
  } > "$capture_tmp"

  {
    echo '[Timer]'
    echo 'OnBootSec='
    echo 'OnUnitActiveSec='
    echo 'OnCalendar='
    echo "OnCalendar=*-*-* *:${upload_minutes}:00 UTC"
    echo 'Persistent=false'
    echo 'AccuracySec=1s'
  } > "$upload_tmp"

  mv -- "$capture_tmp" "$capture_file"
  mv -- "$upload_tmp" "$upload_file"
}
