#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# queue_manager.sh — decides where to enqueue a captured jpg+meta pair.
# Requires: common.sh (logging), storage_manager.sh (paths and df helpers)
#
# Queue priority:
# 1. RAMDISK — if free space >= RAM_MIN_FREE_MB
# 2. USB — if RAMDISK is low AND USB is mounted AND USB usage < USB_MAX_USED_PCT
# 3. SD card — fallback if no USB available or USB is above threshold
# 4. STOP — if fallback to SD is required and SD usage >= SD_MAX_USED_PCT
#
# Return codes:
# 0  — success
# 30 — SD above threshold → capture should be skipped
# 40 — source files missing

ensure_queue_dirs() {
  mkdir -p "$(ram_queue_dir)" "$(sd_queue_dir)"
  local u
  u="$(usb_queue_dir || true)"
  [[ -n "$u" ]] && mkdir -p "$u"
}

enqueue_pair() {
  local jpg_src="$1"
  local meta_src="$2"

  [[ -f "$jpg_src" && -f "$meta_src" ]] || return 40

  ensure_queue_dirs

  local ram_free
  ram_free="$(fs_free_mb "$(ram_queue_dir)")"

  local dest_dir=""

  if [[ "$ram_free" -ge "${RAM_MIN_FREE_MB:-20}" ]]; then
    dest_dir="$(ram_queue_dir)"
  else
    warn "RAMDISK low: free=${ram_free}MB (min=${RAM_MIN_FREE_MB:-20}MB). Trying spillover..."

    local u
    u="$(usb_queue_dir || true)"

    if [[ -n "$u" ]]; then
      mkdir -p "$u"

      local usb_used
      usb_used="$(fs_used_pct "$u")"

      if [[ "$usb_used" -lt "${USB_MAX_USED_PCT:-90}" ]]; then
        dest_dir="$u"
        info "USB spillover: ${dest_dir} (used=${usb_used}%)"
      else
        warn "USB above threshold: used=${usb_used}% (limit=${USB_MAX_USED_PCT:-90}%) -> fallback to SD"

        local sd_used
        sd_used="$(fs_used_pct "$(sd_queue_dir)")"

        if [[ "$sd_used" -ge "${SD_MAX_USED_PCT:-80}" ]]; then
          warn "SD above threshold: used=${sd_used}% (limit=${SD_MAX_USED_PCT:-80}%) -> capture skipped"
          return 30
        fi

        dest_dir="$(sd_queue_dir)"
      fi
    else
      local sd_used
      sd_used="$(fs_used_pct "$(sd_queue_dir)")"

      if [[ "$sd_used" -ge "${SD_MAX_USED_PCT:-80}" ]]; then
        warn "SD above threshold: used=${sd_used}% (limit=${SD_MAX_USED_PCT:-80}%) -> capture skipped"
        return 30
      fi

      dest_dir="$(sd_queue_dir)"
      info "No USB found. Spillover to SD queue: $dest_dir"
    fi
  fi

  mkdir -p "$dest_dir"

  # Atomic move: write to .tmp first, then rename.
  local base
  base="$(basename "$jpg_src" .jpg)"

  local jpg_tmp="${dest_dir}/${base}.jpg.tmp"
  local meta_tmp="${dest_dir}/${base}.meta.tmp"
  local jpg_dst="${dest_dir}/${base}.jpg"
  local meta_dst="${dest_dir}/${base}.meta"

  mv -f "$jpg_src" "$jpg_tmp"
  mv -f "$meta_src" "$meta_tmp"
  mv -f "$jpg_tmp" "$jpg_dst"
  mv -f "$meta_tmp" "$meta_dst"

  info "Enqueued: ${base} -> ${dest_dir}"
  return 0
}
