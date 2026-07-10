#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# 2 lines added in v1.5.0
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${BASE_DIR}/scripts/system_health.sh"

# meta_build.sh — builds the .meta sidecar file for a captured image.
# The .meta file contains these sections:
#   [system]               — station info, network details, timestamp
#   [phenocam]             — oscars-phenocam software version/build info
#   [system_health]        — Raspberry Pi temperature and throttling state
#   [capture_params_fixed] — fixed capture parameters used for every shot
#   [exif]                 — full EXIF metadata extracted by exiftool

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

# function added in dev/v1.6.0
print_phenocam_version_kv() {
  local build_info="/usr/local/lib/phenocam/BUILD_INFO"
  local version_file="/usr/local/lib/phenocam/VERSION"

  if [[ -r "$build_info" ]]; then
    grep -E '^(software_name|software_version|software_branch|software_commit|installed_at)=' "$build_info" || true
    return 0
  fi

  echo "software_name=oscars-phenocam"

  if [[ -r "$version_file" ]]; then
    echo "software_version=$(head -n 1 "$version_file")"
  else
    echo "software_version=nd"
  fi

  echo "software_branch=nd"
  echo "software_commit=nd"
  echo "installed_at=nd"
}

build_meta() {
  local jpg="$1"
  local meta="$2"

  command -v exiftool >/dev/null 2>&1 || return 11

  local iface ip4 mac now_iso
  iface="$(get_iface)"
  ip4=""
  mac=""
  now_iso="$(date -Is)"

  if [[ -n "$iface" ]]; then
    ip4="$(ip -4 -o addr show "$iface" | awk '{print $4}' | cut -d/ -f1 || true)"
    mac="$(cat "/sys/class/net/$iface/address" 2>/dev/null || true)"
  fi

  {
    echo "[system]"
    echo "sitename=${SITENAME:-}"
    echo "hostname=$(hostname -f 2>/dev/null || hostname)"
    echo "timestamp=${now_iso}"

    # NetCam-compatible alias of the acquisition timestamp.
    echo "datetime_original=\"${now_iso}\""

    echo "tz=${TZ_LABEL:-}"
    echo "utc_offset=${UTC_OFFSET:-}"

    # Upload/network mode currently selected for this station.
    echo "network=${REMOTE_LAYOUT:-general}"

    echo "lat=${SITE_LAT:-nd}"
    echo "lon=${SITE_LON:-nd}"
    echo "elev=${SITE_ELEV_M:-nd}"
    echo "start_date=${SITE_START_DATE:-nd}"
    echo "end_date=${SITE_END_DATE:-nd}"
    echo "nimage=${SITE_NIMAGE:-nd}"

    echo "iface=${iface}"
    echo "ip=${ip4}"
    echo "mac=${mac}"
    echo "image_file=$(basename "$jpg")"
    echo ""
    # two lines added in v1.5.0 for check the temperature of the board
    echo "[system_health]"
    print_system_health_kv
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
