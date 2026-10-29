#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${REPO_ROOT}/.schedule-manager-test.XXXXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

source "${REPO_ROOT}/software/scripts/schedule_manager.sh"

INTERVAL_MIN=30
CAPTURE_MINUTE=13
write_schedule_overrides "$TEST_ROOT"

grep -qx 'OnCalendar=\*-\*-\* \*:13,43:00 UTC' \
  "${TEST_ROOT}/phenocam-capture.timer.d/schedule.conf"
grep -qx 'OnCalendar=\*-\*-\* \*:14,44:00 UTC' \
  "${TEST_ROOT}/phenocam-upload.timer.d/schedule.conf"
grep -qx 'Persistent=false' \
  "${TEST_ROOT}/phenocam-capture.timer.d/schedule.conf"
grep -qx 'Persistent=false' \
  "${TEST_ROOT}/phenocam-upload.timer.d/schedule.conf"

INTERVAL_MIN=15
CAPTURE_MINUTE=4
write_schedule_overrides "$TEST_ROOT"
grep -qx 'OnCalendar=\*-\*-\* \*:04,19,34,49:00 UTC' \
  "${TEST_ROOT}/phenocam-capture.timer.d/schedule.conf"
grep -qx 'OnCalendar=\*-\*-\* \*:05,20,35,50:00 UTC' \
  "${TEST_ROOT}/phenocam-upload.timer.d/schedule.conf"

# Boundary offsets wrap the upload request into the next interval without
# changing the persisted acquisition minute.
INTERVAL_MIN=60
CAPTURE_MINUTE=59
write_schedule_overrides "$TEST_ROOT"
grep -qx 'OnCalendar=\*-\*-\* \*:59:00 UTC' \
  "${TEST_ROOT}/phenocam-capture.timer.d/schedule.conf"
grep -qx 'OnCalendar=\*-\*-\* \*:00:00 UTC' \
  "${TEST_ROOT}/phenocam-upload.timer.d/schedule.conf"

INTERVAL_MIN=5
CAPTURE_MINUTE=4
write_schedule_overrides "$TEST_ROOT"
grep -qx 'OnCalendar=\*-\*-\* \*:04,09,14,19,24,29,34,39,44,49,54,59:00 UTC' \
  "${TEST_ROOT}/phenocam-capture.timer.d/schedule.conf"
grep -qx 'OnCalendar=\*-\*-\* \*:00,05,10,15,20,25,30,35,40,45,50,55:00 UTC' \
  "${TEST_ROOT}/phenocam-upload.timer.d/schedule.conf"

[[ ! -e "${TEST_ROOT}/phenocam-capture.timer.d/schedule.conf.tmp" ]]
[[ ! -e "${TEST_ROOT}/phenocam-upload.timer.d/schedule.conf.tmp" ]]

printf 'schedule manager tests: OK\n'
