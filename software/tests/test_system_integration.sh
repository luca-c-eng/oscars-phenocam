#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

required_files=(
  software/bin/diag_upload.sh
  software/bin/phenocam-configure-schedule.sh
  software/bin/phenocam-capture.sh
  software/bin/phenocam-upload.sh
  software/scripts/capture_vis.sh
  software/scripts/config_read.sh
  software/scripts/cycle.sh
  software/scripts/icos_client.py
  software/scripts/icos_manager.sh
  software/scripts/queue_manager.sh
  software/scripts/schedule_manager.sh
  software/scripts/storage_manager.sh
  software/systemd/phenocam-capture.service
  software/systemd/phenocam-capture.timer
  software/systemd/phenocam-upload.service
  software/systemd/phenocam-upload.timer
)

for relative in "${required_files[@]}"; do
  [[ -f "${REPO_ROOT}/${relative}" ]] || {
    printf 'error: required runtime file is missing: %s\n' "$relative" >&2
    exit 1
  }
done

# This dedicated branch must not expose executable FTP/SFTP backends.
for legacy in upload_ftp.sh upload_sftp.sh uploader_daemon.sh; do
  [[ ! -e "${REPO_ROOT}/software/scripts/${legacy}" ]]
done

# The base timers are safe and operational even before installer-generated
# drop-ins apply the station-specific persistent minute.
grep -Fqx 'OnCalendar=*-*-* *:00,30:00 UTC' \
  "${REPO_ROOT}/software/systemd/phenocam-capture.timer"
grep -Fqx 'OnCalendar=*-*-* *:01,31:00 UTC' \
  "${REPO_ROOT}/software/systemd/phenocam-upload.timer"
grep -Fqx 'Persistent=false' \
  "${REPO_ROOT}/software/systemd/phenocam-capture.timer"
grep -Fqx 'Persistent=false' \
  "${REPO_ROOT}/software/systemd/phenocam-upload.timer"

# Service limits must exceed the sequential client timeouts and the manual
# capture-plus-upload diagnostic must have the wider combined limit.
grep -Fqx 'TimeoutStartSec=1200' \
  "${REPO_ROOT}/software/systemd/phenocam-upload.service"
grep -Fqx 'TimeoutStartSec=1500' \
  "${REPO_ROOT}/software/systemd/phenocam-startup-cycle.service"

# Manual wrappers must propagate failures and must not claim to run at boot.
! grep -Fq 'phenocam-upload.sh" || true' \
  "${REPO_ROOT}/software/bin/phenocam-run.sh"
! grep -Fq 'called by phenocam-init.service' \
  "${REPO_ROOT}/software/bin/phenocam-run.sh"

# USB detach must not delete queue temporary files outside capture.lock.
! grep -Fq 'cleanup_tmp_orphans' \
  "${REPO_ROOT}/software/bin/phenocam-usb-detach.sh"

# The documented settings template must remain a valid 34-field ICOS layout.
source "${REPO_ROOT}/software/scripts/config_read.sh"
read_settings "${REPO_ROOT}/software/config/settings_example.txt"
[[ "${#L[@]}" -eq 34 ]]
[[ "$REMOTE_LAYOUT" == icos ]]
[[ "$CP_ENVIRONMENT" == staging ]]

# File-count validation must inspect the working tree and exclude .git data.
grep -Fq 'find "$INSTALL_DIR" -path "$INSTALL_DIR/.git" -prune' \
  "${REPO_ROOT}/install.sh"

printf 'system integration tests: OK\n'
