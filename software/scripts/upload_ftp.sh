#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# upload_ftp.sh — uploads a jpg+meta pair to an FTP server via curl.
#
# Parameters:
#   $1 = local jpg path
#   $2 = local meta path
#   $3 = ftp_credentials.txt path
#
# ftp_credentials.txt format (positional, one value per line):
#   1) FTP_HOST        e.g. 192.168.1.100
#   2) FTP_PORT        e.g. 21
#   3) FTP_REMOTE_BASE e.g. /phenocams/data
#   4) FTP_USER        e.g. myuser
#   5) FTP_PASS        e.g. mypassword
#
# Remote path structure (created automatically):
#   FTP_REMOTE_BASE / SITENAME / YYYY_MM_DD / filename.jpg
#
# Requirements:
#   - curl available in PATH
#   - FTP server must support passive mode (PASV)
#   - FTP_REMOTE_BASE directory must already exist on the server
#   - SITENAME must be exported in the environment (set by config_read.sh)

read_ftp_credentials() {
  local f="$1"
  [[ -f "$f" ]] || return 1

  # Read non-empty, non-comment lines only.
  mapfile -t L < <(grep -vE '^\s*#' "$f" | sed '/^\s*$/d')

  # Minimum 5 required fields.
  [[ "${#L[@]}" -ge 5 ]] || return 2

  FTP_HOST="${L[0]}"
  FTP_PORT="${L[1]}"
  FTP_REMOTE_BASE="${L[2]}"
  FTP_USER="${L[3]}"
  FTP_PASS="${L[4]}"

  export FTP_HOST FTP_PORT FTP_REMOTE_BASE FTP_USER FTP_PASS
}

upload_pair_ftp() {
  local jpg="$1"
  local meta="$2"
  local credentials="$3"

  # Prerequisite checks
  [[ -f "$jpg" ]]         || return 10
  [[ -f "$meta" ]]        || return 11
  [[ -f "$credentials" ]] || return 12

  command -v curl >/dev/null 2>&1 || return 13

  read_ftp_credentials "$credentials" || return 14

  [[ -n "${FTP_HOST:-}" ]]        || return 15
  [[ -n "${FTP_PORT:-}" ]]        || return 16
  [[ -n "${FTP_REMOTE_BASE:-}" ]] || return 17
  [[ -n "${FTP_USER:-}" ]]        || return 18
  [[ -n "${FTP_PASS:-}" ]]        || return 19

  # Extract date part from filename (format: SITENAME_hostname_YYYY_MM_DD_HHMMSS.jpg)
  local base
  base="$(basename "$jpg" .jpg)"
  local date_part
  date_part="$(echo "$base" | grep -oE '[0-9]{4}_[0-9]{2}_[0-9]{2}' | head -1 || true)"

  # Fallback to current date if extraction fails
  if [[ -z "$date_part" ]]; then
    date_part="$(date +%Y_%m_%d)"
  fi

  local remote_dir="${FTP_REMOTE_BASE}/${SITENAME:-unknown}/${date_part}"
  local ftp_base="ftp://${FTP_HOST}:${FTP_PORT}"

  # Create remote subdirectory (--ftp-create-dirs handles this automatically)
  # The .keep upload may fail on some servers but --ftp-create-dirs is also
  # applied to the actual file uploads below.
  curl --silent --show-error \
       --ftp-create-dirs \
       --user "${FTP_USER}:${FTP_PASS}" \
       -T /dev/null \
       "${ftp_base}${remote_dir}/.keep" 2>/dev/null || true

  # Upload .jpg
  if ! curl --silent --show-error \
            --ftp-create-dirs \
            --user "${FTP_USER}:${FTP_PASS}" \
            -T "$jpg" \
            "${ftp_base}${remote_dir}/$(basename "$jpg")"; then
    return 20
  fi

  # Upload .meta
  if ! curl --silent --show-error \
            --ftp-create-dirs \
            --user "${FTP_USER}:${FTP_PASS}" \
            -T "$meta" \
            "${ftp_base}${remote_dir}/$(basename "$meta")"; then
    return 21
  fi

  return 0
}
