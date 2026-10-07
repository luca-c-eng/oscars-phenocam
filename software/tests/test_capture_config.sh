#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_BASE="${TMPDIR:-/tmp}"
[[ -d "$TEST_TMP_BASE" && -w "$TEST_TMP_BASE" ]] || {
  printf 'error: temporary directory is unavailable: %s\n' "$TEST_TMP_BASE" >&2
  exit 1
}
TEST_ROOT="$(mktemp -d "${TEST_TMP_BASE%/}/phenocam-capture-config-test.XXXXXXXX")"

cleanup() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" && \
        "$TEST_ROOT" == "${TEST_TMP_BASE%/}"/phenocam-capture-config-test.* ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}
trap cleanup EXIT

source "${REPO_ROOT}/software/scripts/config_read.sh"

SETTINGS_23="${TEST_ROOT}/settings-23.txt"
BASE_VALUES=(
  mysite +1 UTC+1 6 22 30 auto phenocam auto 20 80
  /media:/mnt 90 general nd nd nd nd nd nd unknown imx708 30000
)
printf '%s\n' "${BASE_VALUES[@]}" >"$SETTINGS_23"

write_capture_settings() {
  local destination="$1"
  local width="$2"
  local height="$3"

  cp -- "$SETTINGS_23" "$destination"
  printf '%s\n' off privacy "$width" "$height" >>"$destination"

  if [[ "$#" -eq 4 ]]; then
    printf '%s\n' "$4" >>"$destination"
  fi
}

# Existing 25-field configurations receive the OSCARS capture defaults.
SETTINGS_25="${TEST_ROOT}/settings-25.txt"
cp -- "$SETTINGS_23" "$SETTINGS_25"
printf '%s\n' off privacy >>"$SETTINGS_25"
read_settings "$SETTINGS_25"
[[ "$IMAGE_WIDTH" == 2304 && "$WIDTH" == 2304 ]]
[[ "$IMAGE_HEIGHT" == 1296 && "$HEIGHT" == 1296 ]]
[[ "$IMAGE_QUALITY" == 100 && "$QUALITY" == 100 ]]

# A 27-field configuration receives the JPEG quality default.
SETTINGS_27="${TEST_ROOT}/settings-27.txt"
write_capture_settings "$SETTINGS_27" 4608 2592
read_settings "$SETTINGS_27"
[[ "$IMAGE_WIDTH" == 4608 && "$IMAGE_HEIGHT" == 2592 ]]
[[ "$IMAGE_QUALITY" == 100 && "$QUALITY" == 100 ]]

# Every documented Camera Module 3 profile and the quality boundaries work.
for profile in '1536 864 1' '2304 1296 93' '4608 2592 100'; do
  IFS=' ' read -r width height quality <<<"$profile"
  settings="${TEST_ROOT}/settings-${width}x${height}-q${quality}.txt"
  write_capture_settings "$settings" "$width" "$height" "$quality"
  read_settings "$settings"
  [[ "$IMAGE_WIDTH" == "$width" && "$WIDTH" == "$width" ]]
  [[ "$IMAGE_HEIGHT" == "$height" && "$HEIGHT" == "$height" ]]
  [[ "$IMAGE_QUALITY" == "$quality" && "$QUALITY" == "$quality" ]]
done

# Unsupported or mixed dimension pairs are rejected.
for dimensions in '1536 1296' '2304 864' '4000 2000'; do
  IFS=' ' read -r width height <<<"$dimensions"
  settings="${TEST_ROOT}/settings-invalid-${width}x${height}.txt"
  write_capture_settings "$settings" "$width" "$height" 100
  if read_settings "$settings"; then
    printf 'error: unsupported dimensions accepted: %sx%s\n' \
      "$width" "$height" >&2
    exit 1
  fi
done

# JPEG quality values outside the documented integer range are rejected.
for quality in 0 101 93.5 invalid; do
  settings="${TEST_ROOT}/settings-invalid-quality-${quality}.txt"
  write_capture_settings "$settings" 2304 1296 "$quality"
  if read_settings "$settings"; then
    printf 'error: invalid JPEG quality accepted: %s\n' "$quality" >&2
    exit 1
  fi
done

printf 'capture configuration tests: OK\n'
