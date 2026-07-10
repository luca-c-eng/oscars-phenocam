#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

LOG_FILE="/var/log/phenocam/phenocam.log"

log_info() {
  printf '%s [INFO] %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE"
}

log_warn() {
  printf '%s [WARN] %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE"
}

log_err() {
  printf '%s [ERROR] %s\n' "$(date -Is)" "$*" | tee -a "$LOG_FILE" >&2
}

log_info "Startup test cycle: begin"

if [[ ! -x /usr/local/lib/phenocam/bin/phenocam-capture.sh ]]; then
  log_err "Startup test cycle: phenocam-capture.sh not found or not executable"
  exit 1
fi

if [[ ! -x /usr/local/lib/phenocam/bin/phenocam-upload.sh ]]; then
  log_err "Startup test cycle: phenocam-upload.sh not found or not executable"
  exit 1
fi

log_info "Startup test cycle: running capture"

/usr/local/lib/phenocam/bin/phenocam-capture.sh || {
  rc="$?"
  log_err "Startup test cycle: capture failed with exit code ${rc}"
  exit "$rc"
}

log_info "Startup test cycle: running upload"

/usr/local/lib/phenocam/bin/phenocam-upload.sh || {
  rc="$?"
  log_err "Startup test cycle: upload failed with exit code ${rc}"
  exit "$rc"
}

log_info "Startup test cycle: completed successfully"
