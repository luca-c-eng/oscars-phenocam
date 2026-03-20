#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# uploader_daemon.sh — drains all queues by uploading jpg+meta pairs to servers.
# Supports SFTP (SSH key) and FTP (user+password) simultaneously.
# Upload method is selected based on which configuration files are present:
#
#   server.txt non-empty + ftp_credentials.txt non-empty → both SFTP and FTP
#   server.txt non-empty only                            → SFTP only
#   ftp_credentials.txt non-empty only                   → FTP only
#   both empty                                           → warning, no upload
#
# Requires:
#   - common.sh          (logging)
#   - config_read.sh     (SFTP_USER)
#   - net_check.sh       (has_internet)
#   - storage_manager.sh (queue directory paths)
#   - upload_sftp.sh     (upload_pair_sftp)
#   - upload_ftp.sh      (upload_pair_ftp)

list_pairs_in_dir() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  find "$d" -maxdepth 1 -type f -name '*.meta' -printf '%f\n' 2>/dev/null \
    | sed 's/\.meta$//' | sort
}

# upload_dir_once — drains one queue directory via SFTP.
upload_dir_once() {
  local dir="$1" server_list="$2" key_path="$3" known_hosts="$4"
  local base jpg meta

  for base in $(list_pairs_in_dir "$dir"); do
    jpg="$dir/${base}.jpg"
    meta="$dir/${base}.meta"
    [[ -f "$jpg" && -f "$meta" ]] || { warn "Incomplete pair in queue: ${dir}/${base}"; continue; }

    if ! has_internet; then
      warn "Network lost during upload cycle. Stopping drain."
      return 10
    fi

    if upload_pair_sftp "$jpg" "$meta" "$server_list" "$key_path" "$known_hosts"; then
      rm -f "$jpg" "$meta"
      info "SFTP uploaded and removed: ${base} from ${dir}"
    else
      warn "SFTP upload failed for: ${base} (will retry next cycle)"
      return 11
    fi
  done

  return 0
}

# upload_dir_once_ftp — drains one queue directory via FTP.
upload_dir_once_ftp() {
  local dir="$1" credentials="$2"
  local base jpg meta

  for base in $(list_pairs_in_dir "$dir"); do
    jpg="$dir/${base}.jpg"
    meta="$dir/${base}.meta"
    [[ -f "$jpg" && -f "$meta" ]] || { warn "Incomplete pair in queue (ftp): ${dir}/${base}"; continue; }

    if ! has_internet; then
      warn "Network lost during FTP upload cycle. Stopping drain."
      return 10
    fi

    if upload_pair_ftp "$jpg" "$meta" "$credentials"; then
      rm -f "$jpg" "$meta"
      info "FTP uploaded and removed: ${base} from ${dir}"
    else
      warn "FTP upload failed for: ${base} (will retry next cycle)"
      return 11
    fi
  done

  return 0
}

# drain_all_queues — main entry point called by phenocam-upload.sh.
drain_all_queues() {
  local server_list="$1" key_path="$2" known_hosts="$3"

  local ftp_credentials="/etc/phenocam/ftp_credentials.txt"
  local use_sftp=false
  local use_ftp=false

  [[ -s "$server_list" ]]      && use_sftp=true
  [[ -s "$ftp_credentials" ]]  && use_ftp=true

  if [[ "$use_sftp" == false && "$use_ftp" == false ]]; then
    warn "No upload method configured (server.txt and ftp_credentials.txt are both empty)"
    return 0
  fi

  if ! has_internet; then
    warn "No internet route: upload postponed to next cycle"
    return 0
  fi

  local u sd ram
  u="$(usb_queue_dir || true)"
  sd="$(sd_queue_dir)"
  ram="$(ram_queue_dir)"

  # SFTP drain (original behaviour — unchanged)
  if [[ "$use_sftp" == true ]]; then
    [[ -n "$u" ]] && { upload_dir_once "$u" "$server_list" "$key_path" "$known_hosts" || return $?; }
    upload_dir_once "$sd"  "$server_list" "$key_path" "$known_hosts" || return $?
    upload_dir_once "$ram" "$server_list" "$key_path" "$known_hosts" || return $?
  fi

  # FTP drain
  if [[ "$use_ftp" == true ]]; then
    [[ -n "$u" ]] && { upload_dir_once_ftp "$u" "$ftp_credentials" || return $?; }
    upload_dir_once_ftp "$sd"  "$ftp_credentials" || return $?
    upload_dir_once_ftp "$ram" "$ftp_credentials" || return $?
  fi

  return 0
}
