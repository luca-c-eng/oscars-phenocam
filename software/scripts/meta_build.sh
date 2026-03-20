#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# meta_build.sh — builds the .meta sidecar file for a captured image.
# The .meta file contains three sections:
#   [system]             — station info, network details, timestamp
#   [capture_params_fixed] — fixed capture parameters used for every shot
#   [exif]               — full EXIF metadata extracted by exiftool

get_iface() {
  # If IFACE is set in settings, use it; otherwise auto-detect.
  if [[ -n "${IFACE:-}" ]]; then
    echo "$IFACE"; return 0
  fi
  # Auto-detect: first non-loopback interface UP with an IPv4 address.
  ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | while read -r i; do
    ip -4 addr show "$i" | grep -q 'inet ' && { echo "$i"; return 0; }
  done
  echo ""
}

build_meta() {
  local jpg="$1"
  local meta="$2"

  command -v exiftool >/dev/null 2>&1 || return 11

  local iface ip4 mac
  iface="$(get_iface)"
  ip4=""
  mac=""

  if [[ -n "$iface" ]]; then
    ip4="$(ip -4 -o addr show "$iface" | awk '{print $4}' | cut -d/ -f1 || true)"
    mac="$(cat "/sys/class/net/$iface/address" 2>/dev/null || true)"
  fi

  {
    echo "sitename=${SITENAME:-}"
    echo "hostname=$(hostname -f 2>/dev/null || hostname)"
    echo "timestamp=$(date -Is)"
    echo "tz=${TZ_LABEL:-}"
    echo "utc_offset=${UTC_OFFSET:-}"
    echo "iface=${iface}"
    echo "ip=${ip4}"
    echo "mac=${mac}"
    echo "image_file=$(basename "$jpg")"
    echo ""
    echo "[capture_params_fixed]"
    echo "width=${WIDTH:-4608}"
    echo "height=${HEIGHT:-2592}"
    echo "awb=${AWB:-daylight}"
    echo "gain=${GAIN:-1.0}"
    echo "sharpness=${SHARP:-1.0}"
    echo "contrast=${CONTRAST:-1.0}"
    echo "brightness=${BRIGHTNESS:-0}"
    echo "saturation=${SATURATION:-1.0}"
    echo "denoise=${DENOISE:-off}"
    echo "ev=${EV:-0}"
    echo "lens_position=${LENS_POSITION:-0.0}"
    echo "quality=${QUALITY:-100}"
    echo ""
    echo "[exif]"
    exiftool -a -u -g1 "$jpg"
  } >"$meta"
}
