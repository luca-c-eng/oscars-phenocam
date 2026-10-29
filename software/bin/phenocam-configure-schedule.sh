#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

BASE="/usr/local/lib/phenocam"
SETTINGS="/etc/phenocam/settings.txt"
SYSTEMD_DIR="/etc/systemd/system"

[[ "$EUID" -eq 0 ]] || {
  printf 'Run this command with sudo.\n' >&2
  exit 1
}

source "${BASE}/scripts/config_read.sh"
source "${BASE}/scripts/schedule_manager.sh"

read_settings "$SETTINGS" || {
  printf 'Invalid settings file: %s\n' "$SETTINGS" >&2
  exit 2
}
write_schedule_overrides "$SYSTEMD_DIR"
systemctl daemon-reload
if [[ "${PHENOCAM_SCHEDULE_NO_RESTART:-0}" != "1" ]]; then
  systemctl restart phenocam-capture.timer phenocam-upload.timer
fi

printf 'Capture schedule updated: interval=%s minute=%s\n' \
  "$INTERVAL_MIN" "$CAPTURE_MINUTE"
