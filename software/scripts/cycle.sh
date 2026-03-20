#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# cycle.sh — capture cycle orchestrator.
# Handles: time window check, orphan cleanup, image capture,
# metadata build, and queue enqueue (RAMDISK / USB / SD).
# Upload is handled separately by uploader_daemon.sh (dedicated timer).

cycle_once() {
  local settings="$1"
  local ram_base="$2"

  source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
  source "$(dirname "${BASH_SOURCE[0]}")/config_read.sh"
  source "$(dirname "${BASH_SOURCE[0]}")/capture_vis.sh"
  source "$(dirname "${BASH_SOURCE[0]}")/meta_build.sh"
  source "$(dirname "${BASH_SOURCE[0]}")/storage_manager.sh"
  source "$(dirname "${BASH_SOURCE[0]}")/queue_manager.sh"

  read_settings "$settings" || die "Invalid settings.txt: $settings"

  if ! within_window; then
    info "Outside capture window: now=$(date +%H) start=$START_HOUR end=$END_HOUR"
    return 0
  fi

  mkdir -p "$ram_base/staging"

  # Clean up orphan files in staging: remove any .jpg/.meta left over from
  # a previous cycle that failed after capture but before enqueue.
  # Safe to do here because capture.lock is already held by with_lock in
  # phenocam-capture.sh — no other cycle can be writing to staging.
  local orphan
  for orphan in "$ram_base"/staging/*.jpg "$ram_base"/staging/*.meta; do
    [[ -f "$orphan" ]] || continue
    warn "Removing orphan from staging: $(basename "$orphan")"
    rm -f "$orphan" || true
  done

  local ts base jpg meta
  ts="$(date +'%Y_%m_%d_%H%M%S')"
  base="${SITENAME:-site}_$(hostname -s | tr '[:upper:]' '[:lower:]')_${ts}"
  jpg="${ram_base}/staging/${base}.jpg"
  meta="${ram_base}/staging/${base}.meta"

  info "Capture VIS -> $jpg"
  capture_vis "$jpg" || die "Capture failed"

  info "Build meta -> $meta"
  build_meta "$jpg" "$meta" || die "Meta build failed"

  # Enqueue the pair (handles spillover and SD threshold enforcement)
  if enqueue_pair "$jpg" "$meta"; then
    return 0
  else
    local rc=$?
    if [[ "$rc" -eq 30 ]]; then
      # SD above threshold: remove staging files to free RAMDISK space
      rm -f "$jpg" "$meta" || true
      return 0
    fi
    die "enqueue_pair failed with rc=$rc"
  fi
}

# Allow standalone execution:
#   cycle.sh /etc/phenocam/settings.txt /run/phenocam
if [[ "${1:-}" == /* && "${2:-}" == /* ]]; then
  cycle_once "$1" "$2"
fi
