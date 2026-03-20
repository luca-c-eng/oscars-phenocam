#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 077

# common.sh — shared logging functions and utilities.
# Source this file at the beginning of every script.

PROJECT_NAME="phenocam"
LOG_DIR="/var/log/${PROJECT_NAME}"
LOG_FILE="${LOG_DIR}/${PROJECT_NAME}.log"

log()  { mkdir -p "$LOG_DIR"; printf '%s [%s] %s\n' "$(date -Is)" "$1" "$2" >>"$LOG_FILE"; }
info() { log "INFO" "$*"; }
warn() { log "WARN" "$*"; }
err()  { log "ERR"  "$*"; }

die() { err "$*"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

# with_lock <lockfile> <command> [args...]
# Acquires an exclusive non-blocking flock on <lockfile>, then runs <command>.
# Exits with an error if the lock is already held (another instance is running).
with_lock() {
  local lockfile="$1"; shift
  mkdir -p "$(dirname "$lockfile")"
  exec 9>"$lockfile"
  flock -n 9 || die "Lock already held: $lockfile"
  "$@"
}
