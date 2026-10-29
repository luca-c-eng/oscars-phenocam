#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${REPO_ROOT}/.icos-config-test.XXXXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

source "${REPO_ROOT}/software/scripts/config_read.sh"

BASE=(
  IT-Tst +1 UTC+1 6 22 30 auto phenocam auto 20 80 /media:/mnt 90 icos
  nd nd nd nd nd nd rpi3b+ imx708 30000 off metadata 2304 1296 100
)

write_settings() {
  local destination="$1" environment="$2" suffix="$3" minute="$4"
  printf '%s\n' "${BASE[@]}" "$environment" ETC \
    http://meta.icos-cp.eu/resources/stations/ES_IT-Tst \
    http://meta.icos-cp.eu/resources/instruments/ETC_TEST \
    "$suffix" "$minute" >"$destination"
}

SETTINGS="${TEST_ROOT}/settings.txt"
write_settings "$SETTINGS" staging L01_F01 13
read_settings "$SETTINGS"
[[ "$CP_ENVIRONMENT" == staging ]]
[[ "$CP_SUBMITTER_ID" == ETC ]]
[[ "$ICOS_FILENAME_SUFFIX" == L01_F01 ]]
[[ "$CAPTURE_MINUTE" == 13 ]]

# Existing 28-field settings remain usable with safe staging defaults.
printf '%s\n' "${BASE[@]}" >"${TEST_ROOT}/legacy.txt"
read_settings "${TEST_ROOT}/legacy.txt"
[[ "$CP_ENVIRONMENT" == staging ]]
[[ "$ICOS_FILENAME_SUFFIX" == nd ]]
[[ "$CAPTURE_MINUTE" == 0 ]]

for environment in test prod invalid; do
  write_settings "${TEST_ROOT}/invalid-env-${environment}.txt" "$environment" L01_F01 13
  if read_settings "${TEST_ROOT}/invalid-env-${environment}.txt"; then
    printf 'error: invalid CP environment accepted: %s\n' "$environment" >&2
    exit 1
  fi
done

for suffix in '../bad' 'L1 F1' 'lowercase' 'L01_F01_EXTRA'; do
  write_settings "${TEST_ROOT}/invalid-suffix.txt" staging "$suffix" 13
  if read_settings "${TEST_ROOT}/invalid-suffix.txt"; then
    printf 'error: invalid ICOS filename suffix accepted: %s\n' "$suffix" >&2
    exit 1
  fi
done

for minute in 30 59 -1 invalid; do
  write_settings "${TEST_ROOT}/invalid-minute.txt" staging L01_F01 "$minute"
  if read_settings "${TEST_ROOT}/invalid-minute.txt"; then
    printf 'error: invalid capture minute accepted: %s\n' "$minute" >&2
    exit 1
  fi
done

printf 'ICOS configuration tests: OK\n'
