#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-init-ramdisk.sh — safely configures /run/phenocam tmpfs.
# This script intentionally replaces fragile inline Bash inside systemd units.
# It computes a RAMDISK size from total RAM, writes uid/gid-aware mount options,
# starts/restarts the mount when safe, and restores ownership of the runtime dirs.

PHENO_USER="${PHENO_USER:-phenocam}"
MOUNT_FILE="${MOUNT_FILE:-/etc/systemd/system/run-phenocam.mount}"
MOUNT_POINT="${MOUNT_POINT:-/run/phenocam}"
MIN_RAMDISK_MB="${MIN_RAMDISK_MB:-50}"
RAMDISK_PERCENT="${RAMDISK_PERCENT:-20}"

log() { echo "phenocam-init-ramdisk: $*"; }

[[ -f "$MOUNT_FILE" ]] || { log "missing mount unit: $MOUNT_FILE"; exit 1; }
id "$PHENO_USER" >/dev/null 2>&1 || { log "missing user: $PHENO_USER"; exit 2; }

PHENO_UID="$(id -u "$PHENO_USER")"
PHENO_GID="$(id -g "$PHENO_USER")"

TOTAL_MB="$(awk '/MemTotal/{printf "%d", $2/1024}' /proc/meminfo)"
if [[ ! "$TOTAL_MB" =~ ^[0-9]+$ || "$TOTAL_MB" -le 0 ]]; then
  # Conservative fallback for Raspberry Pi Zero 2W class boards.
  TOTAL_MB=512
fi

RAM_SIZE=$(( TOTAL_MB * RAMDISK_PERCENT / 100 ))
(( RAM_SIZE < MIN_RAMDISK_MB )) && RAM_SIZE="$MIN_RAMDISK_MB"

NEW_OPTIONS="Options=size=${RAM_SIZE}m,mode=0750,uid=${PHENO_UID},gid=${PHENO_GID}"

if grep -q '^Options=' "$MOUNT_FILE"; then
  OLD_OPTIONS="$(grep '^Options=' "$MOUNT_FILE" | tail -1)"
else
  OLD_OPTIONS=""
fi

OPTIONS_CHANGED=false
if [[ "$OLD_OPTIONS" != "$NEW_OPTIONS" ]]; then
  sed -i -E "s#^Options=.*#${NEW_OPTIONS}#" "$MOUNT_FILE"
  OPTIONS_CHANGED=true
  systemctl daemon-reload
  log "updated mount options: ${NEW_OPTIONS}"
else
  log "mount options already correct: ${NEW_OPTIONS}"
fi

mkdir -p "$MOUNT_POINT"

# Avoid deleting queued RAM files during manual service restarts.
if systemctl is-active --quiet run-phenocam.mount; then
  if [[ "$OPTIONS_CHANGED" == true ]]; then
    if find "$MOUNT_POINT" -type f \( -name '*.jpg' -o -name '*.meta' \) -print -quit 2>/dev/null | grep -q .; then
      log "mount active and queue contains files; not restarting mount to avoid data loss"
    else
      systemctl restart run-phenocam.mount
      log "restarted run-phenocam.mount"
    fi
  fi
else
  systemctl start run-phenocam.mount
  log "started run-phenocam.mount"
fi

install -d -o "$PHENO_USER" -g "$PHENO_USER" -m 0750 "$MOUNT_POINT/queue" "$MOUNT_POINT/staging"
chown "$PHENO_USER:$PHENO_USER" "$MOUNT_POINT"
chmod 0750 "$MOUNT_POINT"

log "ready: ${MOUNT_POINT} size=${RAM_SIZE}m uid=${PHENO_UID} gid=${PHENO_GID}"
