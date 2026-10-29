#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${REPO_ROOT}/.queue-manager-test.XXXXXXXX")"

cleanup() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" &&
        "$TEST_ROOT" == "${REPO_ROOT}"/.queue-manager-test.* ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}
trap cleanup EXIT

source "${REPO_ROOT}/software/scripts/storage_manager.sh"
source "${REPO_ROOT}/software/scripts/queue_manager.sh"

info() { :; }
warn() { :; }
ram_queue_dir() { printf '%s\n' "${TEST_ROOT}/ram"; }
sd_queue_dir() { printf '%s\n' "${TEST_ROOT}/sd"; }
usb_queue_dir() { printf '%s\n' "${TEST_USB_QUEUE:-}"; }
fs_free_mb() { printf '100\n'; }
fs_used_pct() { printf '10\n'; }

mkdir -p "${TEST_ROOT}/staging" "$(ram_queue_dir)" "$(sd_queue_dir)"
RAM_MIN_FREE_MB=20

# A complete pair is verified and published with META last; staging originals
# are removed only after both destination files exist.
printf 'jpeg-one\n' >"${TEST_ROOT}/staging/one.jpg"
printf 'meta-one\n' >"${TEST_ROOT}/staging/one.meta"
enqueue_pair \
  "${TEST_ROOT}/staging/one.jpg" \
  "${TEST_ROOT}/staging/one.meta"

[[ "$(<"$(ram_queue_dir)/one.jpg")" == jpeg-one ]]
[[ "$(<"$(ram_queue_dir)/one.meta")" == meta-one ]]
[[ ! -e "${TEST_ROOT}/staging/one.jpg" ]]
[[ ! -e "${TEST_ROOT}/staging/one.meta" ]]
[[ ! -e "$(ram_queue_dir)/one.jpg.tmp" ]]
[[ ! -e "$(ram_queue_dir)/one.meta.tmp" ]]

# Identical final files recover a completed enqueue whose staging cleanup was
# interrupted; different destination content is never overwritten.
printf 'jpeg-two\n' >"${TEST_ROOT}/staging/two.jpg"
printf 'meta-two\n' >"${TEST_ROOT}/staging/two.meta"
cp -- "${TEST_ROOT}/staging/two.jpg" "$(ram_queue_dir)/two.jpg"
cp -- "${TEST_ROOT}/staging/two.meta" "$(ram_queue_dir)/two.meta"
enqueue_pair \
  "${TEST_ROOT}/staging/two.jpg" \
  "${TEST_ROOT}/staging/two.meta"
[[ ! -e "${TEST_ROOT}/staging/two.jpg" ]]
[[ ! -e "${TEST_ROOT}/staging/two.meta" ]]

printf 'jpeg-three\n' >"${TEST_ROOT}/staging/three.jpg"
printf 'meta-three\n' >"${TEST_ROOT}/staging/three.meta"
printf 'different\n' >"$(ram_queue_dir)/three.jpg"
if enqueue_pair \
  "${TEST_ROOT}/staging/three.jpg" \
  "${TEST_ROOT}/staging/three.meta"; then
  printf 'error: conflicting destination was overwritten\n' >&2
  exit 1
else
  [[ "$?" -eq 41 ]]
fi
[[ "$(<"$(ram_queue_dir)/three.jpg")" == different ]]
[[ -e "${TEST_ROOT}/staging/three.jpg" ]]
[[ -e "${TEST_ROOT}/staging/three.meta" ]]

# If final META publication fails, the visible JPEG is rolled back and the
# complete staging pair remains available for a later retry.
REAL_MV="$(command -v mv)"
export REAL_MV
mkdir -p "${TEST_ROOT}/fake-bin"
cat >"${TEST_ROOT}/fake-bin/mv" <<'EOF'
#!/usr/bin/env bash
src="${@: -2:1}"
dst="${@: -1}"
if [[ "$src" == *.meta.tmp && "$dst" == *.meta ]]; then
  exit 1
fi
exec "$REAL_MV" "$@"
EOF
chmod 0755 "${TEST_ROOT}/fake-bin/mv"

printf 'jpeg-four\n' >"${TEST_ROOT}/staging/four.jpg"
printf 'meta-four\n' >"${TEST_ROOT}/staging/four.meta"
ORIGINAL_PATH="$PATH"
PATH="${TEST_ROOT}/fake-bin:${PATH}"
export PATH
if enqueue_pair \
  "${TEST_ROOT}/staging/four.jpg" \
  "${TEST_ROOT}/staging/four.meta"; then
  printf 'error: simulated META publication failure was accepted\n' >&2
  exit 1
else
  [[ "$?" -eq 42 ]]
fi
PATH="$ORIGINAL_PATH"
export PATH
[[ -e "${TEST_ROOT}/staging/four.jpg" ]]
[[ -e "${TEST_ROOT}/staging/four.meta" ]]
[[ ! -e "$(ram_queue_dir)/four.jpg" ]]
[[ ! -e "$(ram_queue_dir)/four.meta" ]]
[[ ! -e "$(ram_queue_dir)/four.jpg.tmp" ]]
[[ ! -e "$(ram_queue_dir)/four.meta.tmp" ]]

# Temporary files from an interrupted publication are removed from RAM, SD
# and the currently mounted USB queue while capture.lock is held by the caller.
TEST_USB_QUEUE="${TEST_ROOT}/usb"
mkdir -p "$TEST_USB_QUEUE"
touch "$(ram_queue_dir)/old.jpg.tmp"
touch "$(sd_queue_dir)/old.meta.tmp"
touch "${TEST_USB_QUEUE}/old.jpg.tmp"
cleanup_all_queue_tmp_orphans
[[ ! -e "$(ram_queue_dir)/old.jpg.tmp" ]]
[[ ! -e "$(sd_queue_dir)/old.meta.tmp" ]]
[[ ! -e "${TEST_USB_QUEUE}/old.jpg.tmp" ]]

printf 'queue manager tests: OK\n'
