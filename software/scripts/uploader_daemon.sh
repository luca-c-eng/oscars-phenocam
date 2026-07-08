#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# uploader_daemon.sh — drains all queues by uploading jpg+meta pairs to servers.
# Supports SFTP (SSH key) and FTP (user+password) simultaneously.
#
# Upload method is selected from effective configuration, not just file size:
# - server.txt: non-empty, non-comment lines => SFTP enabled
# - ftp_credentials.txt: at least 5 non-empty, non-comment lines => FTP enabled
# - both configured => attempt both; delete local pair only after both succeed
# - only one configured => delete local pair after that target succeeds
#
# This avoids false SFTP attempts when server.txt is empty or contains comments.

has_effective_content() {
  local f="$1"
  [[ -f "$f" ]] && grep -qEv '^\s*(#|$)' "$f"
}

effective_lines() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  grep -vE '^\s*#' "$f" | sed -e 's/\r$//' -e '/^\s*$/d'
}

ftp_credentials_configured() {
  local f="$1"
  [[ -f "$f" ]] || return 1

  mapfile -t L < <(effective_lines "$f")
  [[ "${#L[@]}" -ge 5 ]] || return 1

  # Ignore known placeholders from template files.
  [[ "${L[0]}" != "YOUR_FTP_HOST_OR_IP" ]] || return 1
  [[ "${L[1]}" != "YOUR_FTP_PORT" ]] || return 1
  [[ "${L[3]}" != "your_ftp_username" ]] || return 1
  [[ "${L[4]}" != "your_ftp_password" ]] || return 1

  return 0
}

list_pairs_in_dir() {
  local d="$1"
  [[ -d "$d" ]] || return 0

  find "$d" -maxdepth 1 -type f -name '*.meta' -printf '%f\n' 2>/dev/null \
    | sed 's/\.meta$//' \
    | sort
}

upload_pair_to_targets() {
  local dir="$1"
  local base="$2"
  local use_sftp="$3"
  local use_ftp="$4"
  local server_list="$5"
  local key_path="$6"
  local known_hosts="$7"
  local ftp_credentials="$8"

  local jpg="$dir/${base}.jpg"
  local meta="$dir/${base}.meta"

  [[ -f "$jpg" && -f "$meta" ]] || {
    warn "Incomplete pair in queue: ${dir}/${base}"
    return 0
  }

  if ! has_internet; then
    warn "No internet route during upload cycle: upload postponed"
    return 10
  fi

  local failed=false

  if [[ "$use_sftp" == true ]]; then
    if upload_pair_sftp "$jpg" "$meta" "$server_list" "$key_path" "$known_hosts"; then
      info "SFTP uploaded: ${base} from ${dir}"
    else
      warn "SFTP upload failed for: ${base} (will retry next cycle)"
      failed=true
    fi
  fi

  if [[ "$use_ftp" == true ]]; then
    if upload_pair_ftp "$jpg" "$meta" "$ftp_credentials"; then
      info "FTP uploaded: ${base} from ${dir}"
    else
      warn "FTP upload failed for: ${base} (will retry next cycle)"
      failed=true
    fi
  fi

  if [[ "$failed" == false ]]; then
    rm -f "$jpg" "$meta"
    if [[ "$use_sftp" == true && "$use_ftp" == true ]]; then
      info "SFTP+FTP uploaded and removed: ${base} from ${dir}"
    elif [[ "$use_sftp" == true ]]; then
      info "SFTP uploaded and removed: ${base} from ${dir}"
    else
      info "FTP uploaded and removed: ${base} from ${dir}"
    fi
    return 0
  fi

  return 11
}

upload_dir_once() {
  local dir="$1"
  local use_sftp="$2"
  local use_ftp="$3"
  local server_list="$4"
  local key_path="$5"
  local known_hosts="$6"
  local ftp_credentials="$7"

  [[ -d "$dir" ]] || return 0

  local base rc=0
  while IFS= read -r base; do
    [[ -n "$base" ]] || continue
    upload_pair_to_targets "$dir" "$base" "$use_sftp" "$use_ftp" \
      "$server_list" "$key_path" "$known_hosts" "$ftp_credentials" || rc=$?
  done < <(list_pairs_in_dir "$dir")

  return "$rc"
}

# drain_all_queues — main entry point called by phenocam-upload.sh.
drain_all_queues() {
  local server_list="$1"
  local key_path="$2"
  local known_hosts="$3"
  local ftp_credentials="/etc/phenocam/ftp_credentials.txt"

  local use_sftp=false
  local use_ftp=false

  has_effective_content "$server_list" && use_sftp=true
  ftp_credentials_configured "$ftp_credentials" && use_ftp=true

  if [[ "$use_sftp" == false && "$use_ftp" == false ]]; then
    warn "No upload method configured (server.txt and ftp_credentials.txt have no effective configuration)"
    return 0
  fi

  if ! has_internet; then
    warn "No internet route: upload postponed to next cycle"
    return 0
  fi

  local u sd ram rc=0
  u="$(usb_queue_dir || true)"
  sd="$(sd_queue_dir)"
  ram="$(ram_queue_dir)"

  # Drain order: USB spillover, SD fallback, RAM primary queue.
  if [[ -n "$u" ]]; then
    upload_dir_once "$u" "$use_sftp" "$use_ftp" "$server_list" "$key_path" "$known_hosts" "$ftp_credentials" || rc=$?
  fi
  upload_dir_once "$sd" "$use_sftp" "$use_ftp" "$server_list" "$key_path" "$known_hosts" "$ftp_credentials" || rc=$?
  upload_dir_once "$ram" "$use_sftp" "$use_ftp" "$server_list" "$key_path" "$known_hosts" "$ftp_credentials" || rc=$?

  return "$rc"
}
