#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# storage_manager.sh — queue directory paths and disk space helpers.
#
# Queue priority (managed by queue_manager.sh):
#   1. RAMDISK:  /run/phenocam/queue       (fast, volatile — primary)
#   2. USB:      <mount>/phenocam_queue    (spillover when RAMDISK is low)
#   3. SD card:  /var/lib/phenocam/queue   (fallback when no USB available)

ram_queue_dir() { echo "/run/phenocam/queue"; }
sd_queue_dir()  { echo "/var/lib/phenocam/queue"; }

# find_usb_mount — returns the first writable USB mountpoint found under
# the base paths listed in USB_MOUNT_BASES (colon-separated).
find_usb_mount() {
  local bases="${USB_MOUNT_BASES:-/media:/mnt}"
  local base mp
  IFS=':' read -r -a arr <<< "$bases"
  for base in "${arr[@]}"; do
    [[ -d "$base" ]] || continue
    for mp in "$base"/*; do
      [[ -d "$mp" ]] || continue
      if mountpoint -q "$mp" && [[ -w "$mp" ]]; then
        echo "$mp"
        return 0
      fi
    done
  done
  echo ""
}

# usb_queue_dir — returns the phenocam_queue path on the USB, or empty string.
usb_queue_dir() {
  local mp
  mp="$(find_usb_mount)"
  [[ -n "$mp" ]] && echo "$mp/phenocam_queue" || echo ""
}

# usb_is_mounted — returns 0 if a USB drive is currently mounted, 1 otherwise.
usb_is_mounted() {
  local mp
  mp="$(find_usb_mount)"
  [[ -n "$mp" ]]
}

# cleanup_tmp_orphans <dir> — removes orphan .tmp files in a queue directory.
# Call only when no capture cycle is active (lock not held).
cleanup_tmp_orphans() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local f
  for f in "$dir"/*.tmp; do
    [[ -f "$f" ]] || continue
    warn "Removing orphan .tmp file: $(basename "$f")"
    rm -f "$f" || true
  done
}

# fs_used_pct <path> — returns the used percentage of the filesystem containing <path>.
fs_used_pct() {
  local p="$1"
  df -P "$p" | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

# fs_free_mb <path> — returns the free space in MB of the filesystem containing <path>.
fs_free_mb() {
  local p="$1"
  df -Pm "$p" | awk 'NR==2 {print $4}'
}
