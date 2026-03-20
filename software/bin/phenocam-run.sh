#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-run.sh — manual entrypoint: runs one capture cycle then attempts upload.
# Also called by phenocam-init.service at every boot to run an immediate
# capture+upload cycle as a system health check.
# In production, use phenocam-capture.timer + phenocam-upload.timer instead.

BASE="/usr/local/lib/phenocam"
RAM="/run/phenocam"

"${BASE}/bin/phenocam-capture.sh"
"${BASE}/bin/phenocam-upload.sh" || true
