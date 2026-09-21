#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_TMP_BASE="${TMPDIR:-/tmp}"
[[ -d "$TEST_TMP_BASE" && -w "$TEST_TMP_BASE" ]] || {
  printf 'error: temporary directory is unavailable: %s\n' "$TEST_TMP_BASE" >&2
  exit 1
}
TEST_ROOT="$(mktemp -d "${TEST_TMP_BASE%/}/phenocam-manager-test.XXXXXXXX")"

cleanup() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" && \
        "$TEST_ROOT" == "${TEST_TMP_BASE%/}"/phenocam-manager-test.* ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}
trap cleanup EXIT

METADATA_PYTHON="$(command -v python3)"
DETECTION_METADATA_TOOL="${REPO_ROOT}/software/scripts/detection_metadata.py"
VISION_EDGE_ROOT="${TEST_ROOT}/vision"
VISION_EDGE_PYTHON="/bin/true"
VISION_EDGE_MODEL="${VISION_EDGE_ROOT}/models/yolo26n-phenocam.onnx"
VISION_EDGE_RECEIPT="${VISION_EDGE_ROOT}/models/yolo26n-phenocam.json"

RAM_QUEUE="${TEST_ROOT}/ram"
SD_QUEUE="${TEST_ROOT}/sd"
mkdir -p "$VISION_EDGE_ROOT/models" "$RAM_QUEUE" "$SD_QUEUE"
: >"$VISION_EDGE_MODEL"
: >"$VISION_EDGE_RECEIPT"

info() { :; }
warn() { :; }
ram_queue_dir() { printf '%s\n' "$RAM_QUEUE"; }
sd_queue_dir() { printf '%s\n' "$SD_QUEUE"; }
usb_queue_dir() { printf '\n'; }

source "${REPO_ROOT}/software/scripts/detection_manager.sh"

new_pair() {
  local stem="$1"
  printf 'jpeg\n' >"${stem}.jpg"
  printf '[system]\nsitename=test\n' >"${stem}.meta"
}

append_vision_false() {
  local meta="$1"
  {
    printf '\n[detection]\n'
    printf '%s\n' \
      'detected=false' \
      'software_name=phenocam-detection' \
      'software_version=0.2.3' \
      'model_id=yolo26n-phenocam' \
      'model_version=0.1.6' \
      'annotated_image=' \
      'privacy_image=' \
      'classes=' \
      'total_count=0'
  } >>"$meta"
}

append_vision_privacy_true() {
  local meta="$1"
  local image_name
  image_name="$(basename -- "${meta%.meta}.jpg")"
  {
    printf '\n[detection]\n'
    printf '%s\n' \
      'detected=true' \
      'software_name=phenocam-detection' \
      'software_version=0.2.3' \
      'model_id=yolo26n-phenocam' \
      'model_version=0.1.6' \
      'annotated_image=' \
      "privacy_image=${image_name}" \
      'classes=person' \
      'person_count=1' \
      'total_count=1'
  } >>"$meta"
}

assert_state() {
  local expected="$1"
  local meta="$2"
  local actual
  actual="$(_metadata_state "$meta")"
  [[ "$actual" == "$expected" ]]
}

# OFF creates the durable state without invoking inference.
pair="${RAM_QUEUE}/off"
new_pair "$pair"
VISION_EDGE_ENABLED=off
VISION_EDGE_MODE=privacy
process_detection_pair "${pair}.meta"
assert_state off "${pair}.meta"
detection_pair_ready "${pair}.meta"

# A completed Vision Edge section is enriched without running inference again.
pair="${RAM_QUEUE}/recovery"
new_pair "$pair"
append_vision_false "${pair}.meta"
VISION_EDGE_ENABLED=on
VISION_EDGE_MODE=metadata
process_detection_pair "${pair}.meta"
assert_state ready "${pair}.meta"

# A pending ON pair runs once; later cycles skip it.
pair="${RAM_QUEUE}/once"
new_pair "$pair"
VISION_EDGE_ENABLED=on
VISION_EDGE_MODE=privacy
vision_calls=0
_run_vision_edge() {
  vision_calls=$((vision_calls + 1))
  append_vision_privacy_true "$2"
}
process_detection_pair "${pair}.meta"
process_detection_pair "${pair}.meta"
[[ "$vision_calls" -eq 1 ]]
assert_state ready "${pair}.meta"
detection_pair_ready "${pair}.meta"

# A pending pair cannot pass the upload readiness gate.
pair="${RAM_QUEUE}/pending"
new_pair "$pair"
if detection_pair_ready "${pair}.meta"; then
  exit 1
fi

# Delete-mode recovery removes metadata left after partial pair deletion.
pair="${RAM_QUEUE}/delete"
new_pair "$pair"
VISION_EDGE_ENABLED=on
VISION_EDGE_MODE=delete
_run_vision_edge() {
  rm -f -- "$1"
  return 1
}
process_detection_pair "${pair}.meta"
[[ ! -e "${pair}.jpg" && ! -e "${pair}.meta" ]]

# Invalid metadata remains queued and is never upload-ready.
pair="${SD_QUEUE}/invalid"
new_pair "$pair"
append_vision_false "${pair}.meta"
printf 'total_count=1\n' >>"${pair}.meta"
process_detection_pair "${pair}.meta" 2>/dev/null || true
[[ -f "${pair}.jpg" && -f "${pair}.meta" ]]
if detection_pair_ready "${pair}.meta" 2>/dev/null; then
  exit 1
fi

printf 'detection_manager tests: OK\n'
