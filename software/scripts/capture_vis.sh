#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# capture_vis.sh — VIS image capture wrapper.
# Tries rpicam-still first, falls back to libcamera-still for compatibility.
# All capture parameters use environment variable overrides with sensible defaults.

pick_capture_cmd() {
  if command -v rpicam-still >/dev/null 2>&1; then
    echo "rpicam-still"
  elif command -v libcamera-still >/dev/null 2>&1; then
    echo "libcamera-still"
  else
    echo ""
  fi
}

capture_vis() {
  local out_jpg="$1"

  local cmd
  cmd="$(pick_capture_cmd)"
  [[ -n "$cmd" ]] || return 10

  # Capture parameters — all fixed for PhenoCam use case.
  # Override via environment variables if needed.
  local WIDTH="${WIDTH:-4608}"
  local HEIGHT="${HEIGHT:-2592}"
  local AWB="${AWB:-daylight}"
  local GAIN="${GAIN:-1.0}"
  local SHARP="${SHARP:-1.0}"
  local CONTRAST="${CONTRAST:-1.0}"
  local BRIGHTNESS="${BRIGHTNESS:-0}"
  local SATURATION="${SATURATION:-1.0}"
  local DENOISE="${DENOISE:-off}"
  local EV="${EV:-0}"
  local LENS_POSITION="${LENS_POSITION:-0.0}"
  local QUALITY="${QUALITY:-100}"

  "$cmd" -o "$out_jpg" \
    --width "$WIDTH" --height "$HEIGHT" \
    --awb "$AWB" --gain "$GAIN" \
    --sharpness "$SHARP" --contrast "$CONTRAST" \
    --brightness "$BRIGHTNESS" --saturation "$SATURATION" \
    --denoise "$DENOISE" --ev "$EV" \
    --lens-position "$LENS_POSITION" --quality "$QUALITY"
}
