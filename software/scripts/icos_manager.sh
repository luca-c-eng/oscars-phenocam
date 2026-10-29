#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# icos_manager.sh — creates immutable daily Level-0 products and uploads them
# through the ICOS Carbon Portal standard two-step workflow.

ICOS_OUTBOX_DIR="${ICOS_OUTBOX_DIR:-/var/lib/phenocam/icos-outbox}"
ICOS_RECEIPT_DIR="${ICOS_RECEIPT_DIR:-/var/lib/phenocam/icos-receipts}"
ICOS_CREDENTIALS_FILE="${ICOS_CREDENTIALS_FILE:-/etc/phenocam/cp_credentials.txt}"
ICOS_CLIENT="${ICOS_CLIENT:-/usr/local/lib/phenocam/scripts/icos_client.py}"
ICOS_PYTHON="${ICOS_PYTHON:-/usr/bin/python3}"

_icos_pair_day() {
  local path="$1" base stem
  base="$(basename -- "$path")"
  stem="${base%.*}"

  if [[ "$stem" =~ ^(.+)_([0-9]{4})_([0-9]{2})_([0-9]{2})_([0-9]{6})$ ]] && \
     [[ "${BASH_REMATCH[1]}" == "$SITENAME" ]]; then
    printf '%s%s%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
    return 0
  fi

  return 1
}

_icos_set_queue_dirs() {
  local usb
  ICOS_QUEUE_DIRS=()
  usb="$(usb_queue_dir || true)"
  [[ -n "$usb" ]] && ICOS_QUEUE_DIRS+=("$usb")
  ICOS_QUEUE_DIRS+=("$(sd_queue_dir)" "$(ram_queue_dir)")
}

_icos_credentials_configured() {
  local -a credentials=()
  [[ -f "$ICOS_CREDENTIALS_FILE" && ! -L "$ICOS_CREDENTIALS_FILE" ]] || return 1
  mapfile -t credentials < "$ICOS_CREDENTIALS_FILE" || return 1
  [[ "${#credentials[@]}" -eq 2 ]] || return 1
  credentials[0]="${credentials[0]%$'\r'}"
  credentials[1]="${credentials[1]%$'\r'}"
  [[ -n "${credentials[0]}" && -n "${credentials[1]}" ]]
}

icos_identity_configured() {
  [[ "$REMOTE_LAYOUT" == "icos" ]] || return 1
  [[ "$CP_ENVIRONMENT" == "staging" || "$CP_ENVIRONMENT" == "production" ]] || return 1
  [[ "$SITENAME" =~ ^[A-Z]{2}-[A-Za-z0-9]{3}$ ]] || return 1
  [[ "$CP_SUBMITTER_ID" != "nd" && "$CP_SUBMITTER_ID" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [[ "$CP_STATION_URI" =~ ^https?://meta\.icos-cp\.eu/resources/stations/[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "$CP_INSTRUMENT_URI" =~ ^https?://meta\.icos-cp\.eu/resources/instruments/[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "$ICOS_FILENAME_SUFFIX" != "nd" && \
     "$ICOS_FILENAME_SUFFIX" =~ ^[A-Z][A-Z0-9]{1,7}(_[A-Z][A-Z0-9]{1,7})?$ ]]
}

_icos_collect_days() {
  local dir meta day
  local -A seen=()
  ICOS_DAYS=()
  _icos_set_queue_dirs
  shopt -s nullglob
  for dir in "${ICOS_QUEUE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for meta in "$dir"/*.meta; do
      [[ -f "$meta" && ! -L "$meta" ]] || continue
      day="$(_icos_pair_day "$meta" || true)"
      if [[ -n "$day" && -z "${seen[$day]:-}" ]]; then
        seen["$day"]=1
        ICOS_DAYS+=("$day")
      fi
    done
  done
  shopt -u nullglob
}

_icos_day_is_closed() {
  local day="$1" today hour
  today="$(date +%Y%m%d)"
  hour=$((10#$(date +%H)))

  [[ "$day" < "$today" ]] || {
    [[ "$day" == "$today" && "$hour" -ge $((10#$END_HOUR)) ]]
  }
}

_icos_collect_day_entries() {
  local day="$1" destination="$2"
  local dir path pair_day base counterpart
  local -A seen=()
  local -a entries=()

  _icos_set_queue_dirs
  shopt -s nullglob
  for dir in "${ICOS_QUEUE_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    for path in "$dir"/*.jpg "$dir"/*.meta; do
      [[ -f "$path" && ! -L "$path" ]] || continue
      pair_day="$(_icos_pair_day "$path" || true)"
      [[ "$pair_day" == "$day" ]] || continue

      base="$(basename -- "$path")"
      if [[ -n "${seen[$base]:-}" ]]; then
        warn "ICOS day ${day} has duplicate queue entry: ${base}"
        return 1
      fi
      seen["$base"]=1

      if [[ "$path" == *.meta ]]; then
        counterpart="${path%.meta}.jpg"
        if [[ ! -f "$counterpart" || -L "$counterpart" ]]; then
          warn "ICOS day ${day} has incomplete pair: ${base}"
          return 1
        fi
        if ! detection_pair_ready "$path"; then
          warn "ICOS day ${day} waits for detection state: ${base%.meta}"
          return 1
        fi
      else
        counterpart="${path%.jpg}.meta"
        if [[ ! -f "$counterpart" || -L "$counterpart" ]]; then
          warn "ICOS day ${day} has incomplete pair: ${base}"
          return 1
        fi
      fi

      entries+=("$path")
    done
  done
  shopt -u nullglob

  [[ "${#entries[@]}" -gt 0 ]] || return 2
  printf '%s\n' "${entries[@]}" | sort > "$destination"
}

_icos_build_manifest() {
  local entries_file="$1" manifest="$2" path digest
  : > "$manifest"
  while IFS= read -r path; do
    digest="$(sha256sum -- "$path" | awk '{print $1}')" || return 1
    printf '%s\t%s\n' "$digest" "$path" >> "$manifest"
  done < "$entries_file"
}

icos_package_day() {
  local day="$1"
  local filename archive metadata manifest registered receipt blocked environment_file
  local entries_file tmp_archive tmp_manifest tmp_environment checksum iso_day
  local entry
  local -a source_entries=() archive_entries=()

  filename="${SITENAME}_PHEN_${day}_${ICOS_FILENAME_SUFFIX}.zip"
  archive="${ICOS_OUTBOX_DIR}/${filename}"
  metadata="${archive}.metadata.json"
  manifest="${archive}.manifest"
  registered="${archive}.registered"
  receipt="${archive}.uploaded.json"
  blocked="${archive}.blocked"
  environment_file="${archive}.environment"

  [[ ! -f "$receipt" ]] || return 0
  if [[ -f "$archive" && -f "$metadata" && -f "$manifest" && -f "$environment_file" ]]; then
    return 0
  fi

  mkdir -p "$ICOS_OUTBOX_DIR" "$ICOS_RECEIPT_DIR"
  entries_file="$(mktemp "${ICOS_OUTBOX_DIR}/.entries.XXXXXXXX")"
  tmp_archive="${archive}.tmp.zip"
  tmp_manifest="${manifest}.tmp"
  tmp_environment="${environment_file}.tmp"
  rm -f -- "$tmp_archive" "$tmp_manifest" "$tmp_environment"

  local collect_rc=0
  _icos_collect_day_entries "$day" "$entries_file" || collect_rc=$?
  if [[ "$collect_rc" -ne 0 ]]; then
    rm -f -- "$entries_file"
    return "$collect_rc"
  fi
  mapfile -t source_entries < "$entries_file"
  for entry in "${source_entries[@]}"; do
    [[ "$entry" == *.jpg ]] && archive_entries+=("$entry")
  done
  [[ "${#archive_entries[@]}" -gt 0 ]] || {
    rm -f -- "$entries_file"
    return 2
  }

  # etcPhenocamDaily is an uncompressed ZIP archive with images. META sidecars
  # remain local and are covered by the source manifest, but are not inserted
  # into the Carbon Portal data object.
  if ! zip -q -0 -j "$tmp_archive" -- "${archive_entries[@]}"; then
    rm -f -- "$entries_file" "$tmp_archive"
    warn "Could not create ICOS daily archive: ${filename}"
    return 1
  fi

  _icos_build_manifest "$entries_file" "$tmp_manifest" || {
    rm -f -- "$entries_file" "$tmp_archive" "$tmp_manifest"
    return 1
  }
  rm -f -- "$entries_file"

  mv -- "$tmp_archive" "$archive"
  checksum="$(sha256sum -- "$archive" | awk '{print $1}')"
  iso_day="${day:0:4}-${day:4:2}-${day:6:2}"

  if ! "$ICOS_PYTHON" "$ICOS_CLIENT" build-metadata \
      --archive "$archive" \
      --day "$iso_day" \
      --utc-offset "$UTC_OFFSET" \
      --submitter-id "$CP_SUBMITTER_ID" \
      --station-uri "$CP_STATION_URI" \
      --instrument-uri "$CP_INSTRUMENT_URI" \
      --expected-hash "$checksum" \
      --output "$metadata"; then
    rm -f -- "$archive" "$metadata" "$tmp_manifest"
    warn "Could not generate ICOS metadata package: ${filename}"
    return 1
  fi

  printf '%s\n' "$CP_ENVIRONMENT" > "$tmp_environment"
  mv -- "$tmp_manifest" "$manifest"
  mv -- "$tmp_environment" "$environment_file"
  rm -f -- "$registered" "$receipt" "$blocked"
  info "ICOS daily archive prepared: ${filename}"
}

_icos_cleanup_uploaded_archive() {
  local archive="$1"
  local manifest="${archive}.manifest" receipt="${archive}.uploaded.json"
  local expected path actual safe=true removed=true

  [[ -f "$receipt" && -f "$manifest" ]] || return 1
  while IFS=$'\t' read -r expected path; do
    [[ -n "$path" ]] || continue
    [[ -e "$path" ]] || continue
    if [[ ! -f "$path" || -L "$path" ]]; then
      warn "Refusing cleanup of unsafe ICOS source: ${path}"
      safe=false
      continue
    fi
    actual="$(sha256sum -- "$path" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
      warn "Refusing cleanup of changed ICOS source: ${path}"
      safe=false
    fi
  done < "$manifest"

  [[ "$safe" == true ]] || return 1
  while IFS=$'\t' read -r expected path; do
    [[ -n "$path" ]] || continue
    if [[ -e "$path" ]] && ! rm -f -- "$path"; then
      warn "Could not remove uploaded ICOS source: ${path}"
      removed=false
    fi
  done < "$manifest"

  while IFS=$'\t' read -r expected path; do
    [[ -n "$path" ]] || continue
    if [[ -e "$path" ]]; then
      warn "Uploaded ICOS source is still present: ${path}"
      removed=false
    fi
  done < "$manifest"

  [[ "$removed" == true ]] || return 1

  mkdir -p "$ICOS_RECEIPT_DIR"
  mv -- "$receipt" "${ICOS_RECEIPT_DIR}/$(basename -- "$archive").receipt.json"
  rm -f -- "$archive" "${archive}.metadata.json" "$manifest" \
    "${archive}.registered" "${archive}.blocked" "${archive}.environment"
  info "ICOS upload completed and local source pairs removed: $(basename -- "$archive")"
}

icos_cleanup_completed_uploads() {
  local receipt archive
  [[ -d "$ICOS_OUTBOX_DIR" ]] || return 0
  shopt -s nullglob
  for receipt in "$ICOS_OUTBOX_DIR"/*.zip.uploaded.json; do
    [[ -f "$receipt" ]] || continue
    archive="${receipt%.uploaded.json}"
    _icos_cleanup_uploaded_archive "$archive" || true
  done
  shopt -u nullglob
}

icos_upload_outbox() {
  local archive rc output_file error_detail
  [[ -d "$ICOS_OUTBOX_DIR" ]] || return 0

  if ! _icos_credentials_configured; then
    warn "ICOS upload postponed: configure ${ICOS_CREDENTIALS_FILE}"
    return 0
  fi
  if ! has_internet; then
    warn "No internet route: ICOS upload postponed"
    return 0
  fi

  shopt -s nullglob
  for archive in "$ICOS_OUTBOX_DIR"/*.zip; do
    [[ -f "$archive" && ! -L "$archive" ]] || continue
    [[ -f "${archive}.uploaded.json" ]] && continue
    [[ -f "${archive}.blocked" ]] && continue
    [[ -f "${archive}.metadata.json" && -f "${archive}.manifest" && \
       -f "${archive}.environment" ]] || continue
    if [[ "$(<"${archive}.environment")" != "$CP_ENVIRONMENT" ]]; then
      warn "ICOS product belongs to another environment and is retained: $(basename -- "$archive")"
      continue
    fi
    output_file="${archive}.last-error.tmp"
    rc=0
    "$ICOS_PYTHON" "$ICOS_CLIENT" upload \
        --environment "$CP_ENVIRONMENT" \
        --archive "$archive" \
        --metadata "${archive}.metadata.json" \
        --credentials "$ICOS_CREDENTIALS_FILE" \
        --registered "${archive}.registered" \
        --receipt "${archive}.uploaded.json" 2>"$output_file" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      rm -f -- "$output_file"
      _icos_cleanup_uploaded_archive "$archive" || true
      continue
    fi

    if [[ "$rc" -eq 20 ]]; then
      mv -- "$output_file" "${archive}.blocked"
      warn "ICOS archive blocked by configuration or validation error: $(basename -- "$archive")"
    else
      error_detail="$(tr '\n' ' ' < "$output_file" | cut -c1-500)"
      if [[ -n "$error_detail" ]]; then
        warn "ICOS upload failed and will be retried: $(basename -- "$archive"): ${error_detail}"
      else
        warn "ICOS upload failed and will be retried: $(basename -- "$archive")"
      fi
      rm -f -- "$output_file"
    fi
  done
  shopt -u nullglob
}

process_icos_queues() {
  local day
  need_cmd zip
  need_cmd sha256sum
  [[ -x "$ICOS_PYTHON" && -f "$ICOS_CLIENT" && ! -L "$ICOS_CLIENT" ]] || {
    warn "ICOS client runtime is unavailable"
    return 1
  }

  icos_cleanup_completed_uploads

  if ! icos_identity_configured; then
    warn "ICOS upload identity is not configured; queued pairs are retained"
    return 0
  fi

  _icos_collect_days
  for day in "${ICOS_DAYS[@]}"; do
    [[ -n "$day" ]] || continue
    _icos_day_is_closed "$day" || continue
    icos_package_day "$day" || true
  done

  icos_upload_outbox
}
