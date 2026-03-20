#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-capture.sh — entrypoint for the capture cycle.
# Called by phenocam-capture.service (systemd timer).
# Acquires a lock to prevent concurrent runs, then executes cycle_once().

BASE="/usr/local/lib/phenocam"
SETTINGS="/etc/phenocam/settings.txt"
RAM="/run/phenocam"

source "${BASE}/scripts/common.sh"
with_lock "${RAM}/capture.lock" bash -c "source '${BASE}/scripts/cycle.sh'; cycle_once '${SETTINGS}' '${RAM}'"
