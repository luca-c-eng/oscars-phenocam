#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# phenocam-run.sh — manual entrypoint: runs one capture cycle then attempts upload.
# No systemd unit invokes this wrapper automatically. In production, use
# phenocam-capture.timer and phenocam-upload.timer; use this command only when
# an additional off-schedule acquisition is intentional.

BASE="/usr/local/lib/phenocam"
RAM="/run/phenocam"

"${BASE}/bin/phenocam-capture.sh"
"${BASE}/bin/phenocam-upload.sh"
