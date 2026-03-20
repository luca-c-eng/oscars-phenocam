#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-upload.sh — entrypoint for the upload drain cycle.
# Called by phenocam-upload.service (systemd timer).
# Acquires a lock to prevent concurrent runs, then drains all queues.

BASE="/usr/local/lib/phenocam"
SETTINGS="/etc/phenocam/settings.txt"
SERVERS="/etc/phenocam/server.txt"
KEY="/etc/phenocam/keys/phenocam_key"
KNOWN_HOSTS="/etc/phenocam/known_hosts"
RAM="/run/phenocam"

source "${BASE}/scripts/common.sh"
with_lock "${RAM}/upload.lock" bash -c \
  "source '${BASE}/scripts/common.sh'; \
   source '${BASE}/scripts/config_read.sh'; \
   source '${BASE}/scripts/net_check.sh'; \
   source '${BASE}/scripts/storage_manager.sh'; \
   source '${BASE}/scripts/upload_sftp.sh'; \
   source '${BASE}/scripts/upload_ftp.sh'; \
   source '${BASE}/scripts/uploader_daemon.sh'; \
   read_settings '${SETTINGS}' || exit 2; \
   drain_all_queues '${SERVERS}' '${KEY}' '${KNOWN_HOSTS}'"
