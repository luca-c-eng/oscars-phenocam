#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-usb-detach.sh — called by udev when a USB drive is removed.
# Works even if the drive was removed without prior unmount (hot-removal).
# Performs a lazy unmount to cleanly release the mount point and logs the
# event. Queue temporary-file cleanup is performed only by a capture cycle
# while capture.lock is held.
# The next capture cycle will automatically fall back to SD queue.

BASE="/usr/local/lib/phenocam"
SETTINGS="/etc/phenocam/settings.txt"
source "${BASE}/scripts/common.sh"
source "${BASE}/scripts/config_read.sh"

# Scan USB mount bases for stale mounts (device removed but still in mount table)
USB_BASES="${USB_MOUNT_BASES:-/media:/mnt}"
if [[ -r "$SETTINGS" ]]; then
  if read_settings "$SETTINGS"; then
    USB_BASES="$USB_MOUNT_BASES"
  else
    warn "USB detach: invalid settings; scanning default mount bases"
    USB_BASES="/media:/mnt"
  fi
fi
IFS=':' read -r -a arr <<< "$USB_BASES"

for base in "${arr[@]}"; do
  [[ -d "$base" ]] || continue
  for mp in "$base"/*; do
    [[ -d "$mp" ]] || continue
    # If still in mount table but device no longer responds → lazy unmount
    if mountpoint -q "$mp" 2>/dev/null; then
      if ! ls "$mp" >/dev/null 2>&1; then
        warn "USB removed without unmount at ${mp}. Performing lazy unmount..."
        umount -l "$mp" 2>/dev/null || true
        info "Lazy unmount completed for ${mp}. Falling back to SD queue."
      fi
    fi
  done
done

info "USB detach handling complete. Next capture cycle will use SD queue."
