#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# upload_sftp.sh — uploads a jpg+meta pair to one or more SFTP servers.
#
# Parameters:
#   $1 = local jpg path
#   $2 = local meta path
#   $3 = server.txt file (one hostname per line)
#   $4 = private SSH key path
#   $5 = known_hosts file path
#
# Requirements:
#   - SFTP_USER must be exported in the environment (set by config_read.sh)
#   - StrictHostKeyChecking is enforced (known_hosts must contain the server fingerprint)
#   - Remote directory: configured as TBD_REMOTE_DIR (update when server is available)

upload_pair_sftp() {
  local jpg="$1"
  local meta="$2"
  local server_list="$3"
  local key_path="$4"
  local known_hosts="$5"

  # Prerequisite checks
  [[ -f "$jpg" ]]         || return 10
  [[ -f "$meta" ]]        || return 11
  [[ -f "$server_list" ]] || return 12
  [[ -f "$key_path" ]]    || return 13
  [[ -f "$known_hosts" ]] || return 14
  [[ -n "${SFTP_USER:-}" ]] || return 15

  command -v sftp >/dev/null 2>&1 || return 16

  # Remote directory — update this when the server contract is defined.
  local remote_dir="TBD_REMOTE_DIR"

  local host
  while IFS= read -r host; do
    # Skip empty lines and comments
    [[ -z "$host" || "$host" =~ ^# ]] && continue

    local batch_file
    batch_file="$(mktemp)"

    {
      echo "mkdir ${remote_dir}"
      echo "cd ${remote_dir}"
      echo "put \"${jpg}\""
      echo "put \"${meta}\""
    } > "$batch_file"

    if ! sftp \
        -b "$batch_file" \
        -i "$key_path" \
        -oBatchMode=yes \
        -oStrictHostKeyChecking=yes \
        -oUserKnownHostsFile="$known_hosts" \
        "${SFTP_USER}@${host}"; then
      rm -f "$batch_file"
      return 20
    fi

    rm -f "$batch_file"
  done < "$server_list"

  return 0
}
