#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# capture_vis.sh — VIS image capture wrapper.
# Tries rpicam-still first, falls back to libcamera-still for compatibility.
# All capture parameters use environment variable overrides with sensible defaults.
#
# Notes from Zero 2W validation:
# - CAPTURE_TIMEOUT is the rpicam/libcamera warm-up time before capture, in ms.
#   It is not an operating-system level safety limit.
# - A 30000 ms value is expected and valid on RPi Zero 2W.
# - A separate GNU timeout guard prevents indefinite camera hangs.
# - -n/--nopreview is used for headless/Lite installs and reduces preview overhead.

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

  command -v timeout >/dev/null 2>&1 || return 11

  # Capture parameters. Defaults mirror the validated Camera Module 3 setup.
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

  # rpicam/libcamera warm-up time before still capture, in milliseconds.
  local CAPTURE_TIMEOUT="${CAPTURE_TIMEOUT:-30000}"
  if [[ ! "$CAPTURE_TIMEOUT" =~ ^[0-9]+$ ]]; then
    CAPTURE_TIMEOUT="30000"
  fi

  # OS-level guard. Keep this deliberately wider than CAPTURE_TIMEOUT.
  # Example: CAPTURE_TIMEOUT=30000 => guard 180 s.
  local GUARD_TIMEOUT_SEC="${CAPTURE_GUARD_TIMEOUT_SEC:-}"
  if [[ -z "$GUARD_TIMEOUT_SEC" ]]; then
    GUARD_TIMEOUT_SEC=$(( (CAPTURE_TIMEOUT + 999) / 1000 + 150 ))
    (( GUARD_TIMEOUT_SEC < 180 )) && GUARD_TIMEOUT_SEC=180
  fi
  if [[ ! "$GUARD_TIMEOUT_SEC" =~ ^[0-9]+$ ]]; then
    GUARD_TIMEOUT_SEC="180"
  fi

  timeout --kill-after=10s "${GUARD_TIMEOUT_SEC}s" \
    "$cmd" -n -o "$out_jpg" \
      --width "$WIDTH" --height "$HEIGHT" \
      --awb "$AWB" --gain "$GAIN" \
      --sharpness "$SHARP" --contrast "$CONTRAST" \
      --brightness "$BRIGHTNESS" --saturation "$SATURATION" \
      --denoise "$DENOISE" --ev "$EV" \
      --lens-position "$LENS_POSITION" --quality "$QUALITY" \
      --timeout "$CAPTURE_TIMEOUT"
}
