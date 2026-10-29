#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# diag_upload.sh — validates ICOS prerequisites without authenticating or
# attempting a transfer. Credential contents are never printed.

BASE="/usr/local/lib/phenocam"
SETTINGS="/etc/phenocam/settings.txt"
CREDENTIALS="/etc/phenocam/cp_credentials.txt"
OUTBOX="/var/lib/phenocam/icos-outbox"

source "${BASE}/scripts/config_read.sh"
source "${BASE}/scripts/icos_manager.sh"

if ! read_settings "$SETTINGS"; then
  printf 'settings: INVALID (%s)\n' "$SETTINGS"
  exit 2
fi

printf 'environment: %s\n' "$CP_ENVIRONMENT"
printf 'station:     %s\n' "$SITENAME"
printf 'submitter:   %s\n' "$CP_SUBMITTER_ID"
printf 'station URI: %s\n' "$CP_STATION_URI"
printf 'instrument:  %s\n' "$CP_INSTRUMENT_URI"
printf 'ZIP suffix:  %s\n' "$ICOS_FILENAME_SUFFIX"
printf 'schedule:    every %s min at offset %s\n' "$INTERVAL_MIN" "$CAPTURE_MINUTE"

if icos_identity_configured; then
  printf 'ICOS identity: OK\n'
else
  printf 'ICOS identity: INCOMPLETE OR INVALID\n'
fi

if _icos_credentials_configured; then
  printf 'credentials: OK (contents hidden)\n'
else
  printf 'credentials: INCOMPLETE OR MISSING (%s)\n' "$CREDENTIALS"
fi

if [[ -d "$OUTBOX" ]]; then
  find "$OUTBOX" -maxdepth 1 -type f -name '*.zip' -printf 'outbox: %f\n'
fi
