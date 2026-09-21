#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# detection_manager.sh — process queued pairs once before upload.
# This file is sourced inside upload.lock. It never acquires a second lock.

VISION_EDGE_ROOT="${VISION_EDGE_ROOT:-/opt/phenocam-vision-edge-0.2.3}"
VISION_EDGE_PYTHON="${VISION_EDGE_PYTHON:-${VISION_EDGE_ROOT}/.venv/bin/python}"
VISION_EDGE_MODEL="${VISION_EDGE_MODEL:-${VISION_EDGE_ROOT}/models/yolo26n-phenocam.onnx}"
VISION_EDGE_RECEIPT="${VISION_EDGE_RECEIPT:-${VISION_EDGE_ROOT}/models/yolo26n-phenocam.json}"
DETECTION_METADATA_TOOL="${DETECTION_METADATA_TOOL:-/usr/local/lib/phenocam/scripts/detection_metadata.py}"
METADATA_PYTHON="${METADATA_PYTHON:-/usr/bin/python3}"

_metadata_runtime_ready() {
  [[ -x "$METADATA_PYTHON" ]]
  [[ -f "$DETECTION_METADATA_TOOL" && ! -L "$DETECTION_METADATA_TOOL" ]]
}

_vision_runtime_ready() {
  [[ -x "$VISION_EDGE_PYTHON" ]]
  [[ -f "$VISION_EDGE_MODEL" && ! -L "$VISION_EDGE_MODEL" ]]
  [[ -f "$VISION_EDGE_RECEIPT" && ! -L "$VISION_EDGE_RECEIPT" ]]
}

_metadata_state() {
  local meta="$1"
  "$METADATA_PYTHON" "$DETECTION_METADATA_TOOL" status --meta "$meta"
}

_mark_off() {
  local meta="$1"
  "$METADATA_PYTHON" "$DETECTION_METADATA_TOOL" \
    mark-off --meta "$meta" --mode "$VISION_EDGE_MODE"
}

_mark_on() {
  local meta="$1"
  "$METADATA_PYTHON" "$DETECTION_METADATA_TOOL" \
    mark-on --meta "$meta" --mode "$VISION_EDGE_MODE"
}

_run_vision_edge() {
  local jpg="$1"
  local meta="$2"
  local queue_dir jpg_name meta_name
  queue_dir="$(dirname -- "$jpg")"
  jpg_name="$(basename -- "$jpg")"
  meta_name="$(basename -- "$meta")"

  local -a command=(
    "$VISION_EDGE_PYTHON" -m phenocam
    --input "$jpg_name"
    --model "$VISION_EDGE_MODEL"
    --meta "$meta_name"
  )

  case "$VISION_EDGE_MODE" in
    metadata) ;;
    annotated) command+=(--annotated-output "$jpg_name") ;;
    privacy) command+=(--privacy-output "$jpg_name") ;;
    delete) command+=(--delete-input-on-detection) ;;
    *) return 64 ;;
  esac

  (
    cd -- "$queue_dir"
    PYTHONPATH="$VISION_EDGE_ROOT" PYTHONDONTWRITEBYTECODE=1 "${command[@]}"
  )
}

_recover_partial_delete() {
  local jpg="$1"
  local meta="$2"

  [[ "$VISION_EDGE_MODE" == "delete" ]] || return 1
  [[ ! -e "$jpg" && ! -L "$jpg" ]] || return 1
  [[ -f "$meta" && ! -L "$meta" ]] || return 1

  if rm -f -- "$meta" && [[ ! -e "$meta" && ! -L "$meta" ]]; then
    info "Completed partial detection deletion: $(basename -- "${jpg%.jpg}")"
    return 0
  fi

  return 1
}

process_detection_pair() {
  local meta="$1"
  local jpg="${meta%.meta}.jpg"
  local base state
  base="$(basename -- "${meta%.meta}")"

  if [[ ! -f "$jpg" || -L "$jpg" ]]; then
    warn "Detection skipped incomplete pair: ${base}"
    return 1
  fi

  if ! state="$(_metadata_state "$meta")"; then
    warn "Detection metadata rejected: ${base}"
    return 1
  fi

  case "$state" in
    off|ready)
      return 0
      ;;
    vision)
      if _mark_on "$meta"; then
        info "Detection metadata completed: ${base}"
        return 0
      fi

      warn "Detection metadata completion failed: ${base}"
      return 1
      ;;
    pending) ;;
    *)
      warn "Unknown detection metadata state: ${base}"
      return 1
      ;;
  esac

  if [[ "$VISION_EDGE_ENABLED" == "off" ]]; then
    if _mark_off "$meta"; then
      info "Detection disabled for queued pair: ${base}"
      return 0
    fi

    warn "Detection OFF marker failed: ${base}"
    return 1
  fi

  if [[ "$VISION_EDGE_ENABLED" != "on" ]]; then
    warn "Invalid detection enabled value"
    return 1
  fi

  if ! _vision_runtime_ready; then
    warn "Phenocam Vision Edge runtime is unavailable"
    return 1
  fi

  if ! _run_vision_edge "$jpg" "$meta"; then
    if _recover_partial_delete "$jpg" "$meta"; then
      return 0
    fi

    warn "Detection failed for queued pair: ${base}"
    return 1
  fi

  if [[ ! -e "$jpg" && ! -L "$jpg" && ! -e "$meta" && ! -L "$meta" ]]; then
    if [[ "$VISION_EDGE_MODE" == "delete" ]]; then
      info "Detection deleted queued pair: ${base}"
      return 0
    fi

    warn "Detection unexpectedly removed queued pair: ${base}"
    return 1
  fi

  if [[ ! -f "$jpg" || -L "$jpg" || ! -f "$meta" || -L "$meta" ]]; then
    warn "Detection left incomplete queued pair: ${base}"
    return 1
  fi

  if ! state="$(_metadata_state "$meta")" || [[ "$state" != "vision" ]]; then
    warn "Vision Edge metadata result is invalid: ${base}"
    return 1
  fi

  if ! _mark_on "$meta"; then
    warn "Detection marker write failed: ${base}"
    return 1
  fi

  info "Detection completed: ${base} mode=${VISION_EDGE_MODE}"
  return 0
}

process_detection_dir() {
  local dir="$1"

  [[ -d "$dir" ]] || return 0

  local meta
  while IFS= read -r -d '' meta; do
    process_detection_pair "$meta" || true
  done < <(
    find "$dir" -maxdepth 1 -type f -name '*.meta' -print0 2>/dev/null |
      sort -z
  )
}

process_all_detection_queues() {
  if ! _metadata_runtime_ready; then
    warn "Detection metadata runtime is unavailable"
    return 3
  fi

  local usb sd ram
  usb="$(usb_queue_dir || true)"
  sd="$(sd_queue_dir)"
  ram="$(ram_queue_dir)"

  [[ -n "$usb" ]] && process_detection_dir "$usb"
  process_detection_dir "$sd"
  process_detection_dir "$ram"
}

detection_pair_ready() {
  local meta="$1"
  local state

  state="$(_metadata_state "$meta")" || return 1
  [[ "$state" == "off" || "$state" == "ready" ]]
}
