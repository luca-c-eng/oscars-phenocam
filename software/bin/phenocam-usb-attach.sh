#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-usb-attach.sh — called by udev when a USB drive is plugged in.
# Waits for the automatic mount to complete, then creates the phenocam_queue/
# directory and logs the event.
# The USB will be used automatically by the next capture cycle as spillover
# storage when the RAMDISK falls below RAM_MIN_FREE_MB (see settings.txt).

BASE="/usr/local/lib/phenocam"
source "${BASE}/scripts/common.sh"

# Wait for the automount to complete (udisks2 typically takes ~2-3 seconds)
sleep 3

# Detect the mount point
source "${BASE}/scripts/storage_manager.sh"
mp="$(find_usb_mount)"

if [[ -n "$mp" ]]; then
  info "USB attached and mounted at: ${mp}. Will be used as spillover queue when RAMDISK is low."
  mkdir -p "${mp}/phenocam_queue" || true
  chown phenocam:phenocam "${mp}/phenocam_queue" 2>/dev/null || true
else
  warn "USB attach event received but no mountpoint found. Check filesystem format (must be FAT32)."
fi
