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
#   2) FTP_PORT        e.g. 21, or any provider-defined FTP port such as 22
#   3) FTP_REMOTE_BASE e.g. /phenocams/data
#   4) FTP_USER        e.g. myuser
#   5) FTP_PASS        e.g. mypassword
#
# Important: FTP_PORT is configuration, not protocol detection. If the provider
# exposes FTP on port 22, the URL remains ftp://HOST:22/... . Do not convert it
# to SFTP unless the SFTP configuration is explicitly enabled via server.txt.

read_ftp_credentials() {
  local f="$1"
  [[ -f "$f" ]] || return 1

  # Read non-empty, non-comment lines only. Strip CR to tolerate CRLF edits.
  mapfile -t L < <(grep -vE '^\s*#' "$f" | sed -e 's/\r$//' -e '/^\s*$/d')

  # Minimum 5 required fields.
  [[ "${#L[@]}" -ge 5 ]] || return 2

  FTP_HOST="${L[0]}"
  FTP_PORT="${L[1]}"
  FTP_REMOTE_BASE="${L[2]}"
  FTP_USER="${L[3]}"
  FTP_PASS="${L[4]}"

  [[ "$FTP_PORT" =~ ^[0-9]+$ ]] || return 3

  export FTP_HOST FTP_PORT FTP_REMOTE_BASE FTP_USER FTP_PASS
}

upload_one_ftp() {
  local local_file="$1"
  local remote_url="$2"

  curl --silent --show-error \
       --ftp-pasv \
       --ftp-create-dirs \
       --connect-timeout "${FTP_CONNECT_TIMEOUT:-30}" \
       --max-time "${FTP_MAX_TIME:-300}" \
       --retry "${FTP_RETRY:-2}" \
       --retry-delay "${FTP_RETRY_DELAY:-3}" \
       --user "${FTP_USER}:${FTP_PASS}" \
       -T "$local_file" \
       "$remote_url"
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

  # Build remote directory from filename and configured layout.
  local base year month
  base="$(basename "$jpg" .jpg)"

  year="$(echo "$base" | grep -oE '[0-9]{4}_[0-9]{2}_[0-9]{2}' | head -1 | cut -d_ -f1 || true)"
  month="$(echo "$base" | grep -oE '[0-9]{4}_[0-9]{2}_[0-9]{2}' | head -1 | cut -d_ -f2 || true)"

  # Fallback to current year/month if extraction fails.
  if [[ -z "$year" || -z "$month" ]]; then
    year="$(date +%Y)"
    month="$(date +%m)"
  fi

  local remote_dir ftp_base
  ftp_base="ftp://${FTP_HOST}:${FTP_PORT}"

  case "${REMOTE_LAYOUT:-general}" in
    icos)
      remote_dir="${FTP_REMOTE_BASE%/}/data/${SITENAME:-unknown}"
      ;;
    general)
      remote_dir="${FTP_REMOTE_BASE%/}/${SITENAME:-unknown}/${year}/${month}"
      ;;
    *)
      return 22
      ;;
  esac

  # Create remote subdirectory. This .keep upload may fail on some servers;
  # actual JPG/META uploads below also use --ftp-create-dirs.
  curl --silent --show-error \
       --ftp-pasv \
       --ftp-create-dirs \
       --connect-timeout "${FTP_CONNECT_TIMEOUT:-30}" \
       --max-time "${FTP_MAX_TIME:-120}" \
       --user "${FTP_USER}:${FTP_PASS}" \
       -T /dev/null \
       "${ftp_base}${remote_dir}/.keep" 2>/dev/null || true

  upload_one_ftp "$jpg"  "${ftp_base}${remote_dir}/$(basename "$jpg")"  || return 20
  upload_one_ftp "$meta" "${ftp_base}${remote_dir}/$(basename "$meta")" || return 21

  return 0
}
