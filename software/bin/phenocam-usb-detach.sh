#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-usb-detach.sh — called by udev when a USB drive is removed.
# Works even if the drive was removed without prior unmount (hot-removal).
# Performs a lazy unmount to cleanly release the mount point, cleans up
# any orphan .tmp files on SD, and logs the event.
# The next capture cycle will automatically fall back to SD queue.

BASE="/usr/local/lib/phenocam"
source "${BASE}/scripts/common.sh"
source "${BASE}/scripts/storage_manager.sh"

# Scan USB mount bases for stale mounts (device removed but still in mount table)
USB_BASES="${USB_MOUNT_BASES:-/media:/mnt}"
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

# Clean up any orphan .tmp files on SD (may be left from interrupted writes)
cleanup_tmp_orphans "$(sd_queue_dir)"

info "USB detach handling complete. Next capture cycle will use SD queue."
