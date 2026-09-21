#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-upload.sh — entrypoint for detection and upload drain cycles.
# Called by phenocam-upload.service (systemd timer).
# Acquires one lock for detection and upload, then processes all queues.

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
   source '${BASE}/scripts/detection_manager.sh'; \
   source '${BASE}/scripts/upload_sftp.sh'; \
   source '${BASE}/scripts/upload_ftp.sh'; \
   source '${BASE}/scripts/uploader_daemon.sh'; \
   read_settings '${SETTINGS}' || exit 2; \
   validate_vision_edge_settings || { warn 'Invalid Phenocam Vision Edge configuration'; exit 3; }; \
   process_all_detection_queues || exit 4; \
   drain_all_queues '${SERVERS}' '${KEY}' '${KNOWN_HOSTS}'"
