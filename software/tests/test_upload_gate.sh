#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_BASE="${TMPDIR:-/tmp}"
[[ -d "$TEST_TMP_BASE" && -w "$TEST_TMP_BASE" ]] || {
  printf 'error: temporary directory is unavailable: %s\n' "$TEST_TMP_BASE" >&2
  exit 1
}
TEST_ROOT="$(mktemp -d "${TEST_TMP_BASE%/}/phenocam-upload-test.XXXXXXXX")"

cleanup() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" && \
        "$TEST_ROOT" == "${TEST_TMP_BASE%/}"/phenocam-upload-test.* ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}
trap cleanup EXIT

info() { :; }
warn() { :; }

source "${REPO_ROOT}/software/scripts/uploader_daemon.sh"

new_pair() {
  local stem="$1"
  printf 'jpeg\n' >"${stem}.jpg"
  printf '[system]\nsitename=test\n' >"${stem}.meta"
}

ready=false
internet_available=true
sftp_result=0
ftp_result=0
readiness_calls=0
internet_calls=0
sftp_calls=0
ftp_calls=0

detection_pair_ready() {
  readiness_calls=$((readiness_calls + 1))
  [[ "$ready" == true ]]
}

has_internet() {
  internet_calls=$((internet_calls + 1))
  [[ "$internet_available" == true ]]
}

upload_pair_sftp() {
  sftp_calls=$((sftp_calls + 1))
  return "$sftp_result"
}

upload_pair_ftp() {
  ftp_calls=$((ftp_calls + 1))
  return "$ftp_result"
}

# A pair not marked off/ready is retained without a network or upload attempt.
pair="${TEST_ROOT}/pending"
new_pair "$pair"
upload_pair_to_targets \
  "$TEST_ROOT" pending true false unused unused unused unused
[[ "$readiness_calls" -eq 1 ]]
[[ "$internet_calls" -eq 0 ]]
[[ "$sftp_calls" -eq 0 && "$ftp_calls" -eq 0 ]]
[[ -f "${pair}.jpg" && -f "${pair}.meta" ]]

# A ready pair proceeds through the existing upload path and is removed.
pair="${TEST_ROOT}/ready"
new_pair "$pair"
ready=true
upload_pair_to_targets \
  "$TEST_ROOT" ready true false unused unused unused unused
[[ "$readiness_calls" -eq 2 ]]
[[ "$internet_calls" -eq 1 ]]
[[ "$sftp_calls" -eq 1 && "$ftp_calls" -eq 0 ]]
[[ ! -e "${pair}.jpg" && ! -e "${pair}.meta" ]]

# A target failure keeps both files queued for the next cycle.
pair="${TEST_ROOT}/retry"
new_pair "$pair"
ftp_result=1
if upload_pair_to_targets \
  "$TEST_ROOT" retry true true unused unused unused unused; then
  exit 1
else
  status="$?"
fi
[[ "$status" -eq 11 ]]
[[ "$sftp_calls" -eq 2 && "$ftp_calls" -eq 1 ]]
[[ -f "${pair}.jpg" && -f "${pair}.meta" ]]

printf 'upload gate tests: OK\n'
