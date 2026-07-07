#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# capture_vis.sh — VIS image capture wrapper.
# Tries rpicam-still first, falls back to libcamera-still for compatibility.
# All capture parameters use environment variable overrides with sensible defaults.
#
# Hardware-aware behaviour:
#   BOARD        — set in settings.txt (auto-detected at install time)
#                  rpi3b+ | rpizero2w
#   CAMERA_MODEL — set in settings.txt
#                  imx708 (Camera Module 3) | imx708_noir (V3 NoIR)
#
# The --timeout value controls how long rpicam-still waits before capturing.
# On slower boards (Zero 2W) a longer timeout ensures the ISP has time to
# stabilise before the shot is taken. It does NOT affect image quality.

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

  # ── Capture parameters ───────────────────────────────────────────────────────
  # All read from environment (exported by config_read.sh via settings.txt).
  # Defaults applied here cover the case where the variable is not set.
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

  # ── Timeout ──────────────────────────────────────────────────────────────────
  # Default: 30000 ms (30 s) — safe on both RPi 3B+ and Zero 2W.
  # The Zero 2W is slower; a longer timeout prevents the ISP from being
  # cut off before it has stabilised the exposure and white balance.
  # Image quality is unaffected by this value.
  local CAPTURE_TIMEOUT="${CAPTURE_TIMEOUT:-30000}"

  "$cmd" -o "$out_jpg" \
    --width "$WIDTH" --height "$HEIGHT" \
    --awb "$AWB" --gain "$GAIN" \
    --sharpness "$SHARP" --contrast "$CONTRAST" \
    --brightness "$BRIGHTNESS" --saturation "$SATURATION" \
    --denoise "$DENOISE" --ev "$EV" \
    --lens-position "$LENS_POSITION" --quality "$QUALITY" \
    --timeout "$CAPTURE_TIMEOUT"
}
