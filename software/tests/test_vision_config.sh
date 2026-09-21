#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_BASE="${TMPDIR:-/tmp}"
[[ -d "$TEST_TMP_BASE" && -w "$TEST_TMP_BASE" ]] || {
  printf 'error: temporary directory is unavailable: %s\n' "$TEST_TMP_BASE" >&2
  exit 1
}
TEST_ROOT="$(mktemp -d "${TEST_TMP_BASE%/}/phenocam-config-test.XXXXXXXX")"

cleanup() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" && \
        "$TEST_ROOT" == "${TEST_TMP_BASE%/}"/phenocam-config-test.* ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}
trap cleanup EXIT

source "${REPO_ROOT}/software/scripts/config_read.sh"

SETTINGS_23="${TEST_ROOT}/settings-23.txt"
printf '%s\n' \
  mysite \
  +1 \
  UTC+1 \
  6 \
  22 \
  30 \
  auto \
  phenocam \
  auto \
  20 \
  80 \
  /media:/mnt \
  90 \
  general \
  nd \
  nd \
  nd \
  nd \
  nd \
  nd \
  unknown \
  imx708 \
  30000 \
  >"$SETTINGS_23"

# A v1.7.0 file keeps working and receives the v1.8.0 defaults.
read_settings "$SETTINGS_23"
[[ "$VISION_EDGE_ENABLED" == off ]]
[[ "$VISION_EDGE_MODE" == privacy ]]
validate_vision_edge_settings

# Every documented v1.8.0 value is accepted.
for enabled in on off; do
  for mode in metadata annotated privacy delete; do
    SETTINGS_25="${TEST_ROOT}/settings-${enabled}-${mode}.txt"
    cp -- "$SETTINGS_23" "$SETTINGS_25"
    printf '%s\n%s\n' "$enabled" "$mode" >>"$SETTINGS_25"
    read_settings "$SETTINGS_25"
    [[ "$VISION_EDGE_ENABLED" == "$enabled" ]]
    [[ "$VISION_EDGE_MODE" == "$mode" ]]
    validate_vision_edge_settings
  done
done

# Unsupported values are loaded but rejected by the detection-only validator.
# This separation keeps capture configuration loading backward compatible.
SETTINGS_INVALID_ENABLED="${TEST_ROOT}/settings-invalid-enabled.txt"
cp -- "$SETTINGS_23" "$SETTINGS_INVALID_ENABLED"
printf '%s\n%s\n' yes privacy >>"$SETTINGS_INVALID_ENABLED"
read_settings "$SETTINGS_INVALID_ENABLED"
if validate_vision_edge_settings; then
  exit 1
fi

SETTINGS_INVALID_MODE="${TEST_ROOT}/settings-invalid-mode.txt"
cp -- "$SETTINGS_23" "$SETTINGS_INVALID_MODE"
printf '%s\n%s\n' on 'privacy;id' >>"$SETTINGS_INVALID_MODE"
read_settings "$SETTINGS_INVALID_MODE"
if validate_vision_edge_settings; then
  exit 1
fi

printf 'vision configuration tests: OK\n'
