#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d "${REPO_ROOT}/.icos-manager-test.XXXXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

QUEUE="${TEST_ROOT}/queue"
OUTBOX="${TEST_ROOT}/outbox"
RECEIPTS="${TEST_ROOT}/receipts"
mkdir -p "$QUEUE" "$OUTBOX" "$RECEIPTS"

info() { :; }
warn() { :; }
usb_queue_dir() { printf '\n'; }
sd_queue_dir() { printf '%s\n' "$QUEUE"; }
ram_queue_dir() { printf '%s\n' "${TEST_ROOT}/ram"; }
detection_pair_ready() { return 0; }
has_internet() { return 1; }

ICOS_OUTBOX_DIR="$OUTBOX"
ICOS_RECEIPT_DIR="$RECEIPTS"
ICOS_CLIENT="${REPO_ROOT}/software/scripts/icos_client.py"
ICOS_PYTHON="$(command -v python3)"
ICOS_CREDENTIALS_FILE="${TEST_ROOT}/credentials.txt"
source "${REPO_ROOT}/software/scripts/icos_manager.sh"

SITENAME="IT-Tst"
UTC_OFFSET="+1"
END_HOUR="22"
REMOTE_LAYOUT="icos"
CP_ENVIRONMENT="staging"
CP_SUBMITTER_ID="ETC"
CP_STATION_URI="http://meta.icos-cp.eu/resources/stations/ES_IT-Tst"
CP_INSTRUMENT_URI="http://meta.icos-cp.eu/resources/instruments/ETC_TEST"
ICOS_FILENAME_SUFFIX="L01_F01"

# The two-line credentials file remains valid with or without a final newline;
# any additional line is rejected.
printf 'station@example.org\nsecret' >"$ICOS_CREDENTIALS_FILE"
_icos_credentials_configured
printf '\nextra\n' >>"$ICOS_CREDENTIALS_FILE"
if _icos_credentials_configured; then
  printf 'error: credentials with an additional line were accepted\n' >&2
  exit 1
fi
printf 'station@example.org\nsecret\n' >"$ICOS_CREDENTIALS_FILE"

for timestamp in 070000 073000; do
  stem="${QUEUE}/${SITENAME}_2026_10_27_${timestamp}"
  printf 'jpeg-%s\n' "$timestamp" >"${stem}.jpg"
  printf '[system]\ntimestamp=%s\n' "$timestamp" >"${stem}.meta"
done

icos_identity_configured
icos_package_day 20261027

ARCHIVE="${OUTBOX}/IT-Tst_PHEN_20261027_L01_F01.zip"
[[ -f "$ARCHIVE" ]]
[[ -f "${ARCHIVE}.metadata.json" ]]
[[ -f "${ARCHIVE}.manifest" ]]
[[ "$(<"${ARCHIVE}.environment")" == staging ]]

unzip -Z1 "$ARCHIVE" | sort >"${TEST_ROOT}/zip-entries.txt"
mapfile -t ZIP_ENTRIES <"${TEST_ROOT}/zip-entries.txt"
[[ "${#ZIP_ENTRIES[@]}" -eq 2 ]]
[[ "${ZIP_ENTRIES[0]}" == "IT-Tst_2026_10_27_070000.jpg" ]]
[[ "${ZIP_ENTRIES[1]}" == "IT-Tst_2026_10_27_073000.jpg" ]]
if unzip -Z1 "$ARCHIVE" | grep -q '\.meta$'; then
  printf 'error: META sidecar inserted into image-only ICOS archive\n' >&2
  exit 1
fi
[[ "$(wc -l <"${ARCHIVE}.manifest")" -eq 4 ]]

python3 - "$ARCHIVE" <<'PY'
import json
import sys
import zipfile
from pathlib import Path

archive = Path(sys.argv[1])
with zipfile.ZipFile(archive) as bundle:
    assert bundle.infolist()
    assert all(item.compress_type == zipfile.ZIP_STORED for item in bundle.infolist())
meta = json.loads(Path(str(archive) + ".metadata.json").read_text())
assert meta["fileName"] == archive.name
assert meta["objectSpecification"].endswith("etcPhenocamDaily")
assert meta["specificInfo"]["acquisitionInterval"] == {
    "start": "2026-10-26T23:00:00Z",
    "stop": "2026-10-27T23:00:00Z",
}
PY

printf '{"completedAt":"2026-10-28T00:00:00Z"}\n' >"${ARCHIVE}.uploaded.json"
_icos_cleanup_uploaded_archive "$ARCHIVE"
[[ ! -e "$ARCHIVE" ]]
[[ ! -e "${QUEUE}/${SITENAME}_2026_10_27_070000.jpg" ]]
[[ -f "${RECEIPTS}/IT-Tst_PHEN_20261027_L01_F01.zip.receipt.json" ]]

# Source content that changed after packaging must never be removed merely
# because the remote upload produced a receipt.
stem="${QUEUE}/${SITENAME}_2026_10_26_070000"
printf 'jpeg-original\n' >"${stem}.jpg"
printf '[system]\ntimestamp=original\n' >"${stem}.meta"
icos_package_day 20261026
ARCHIVE_CHANGED="${OUTBOX}/IT-Tst_PHEN_20261026_L01_F01.zip"
printf '{"completedAt":"2026-10-27T00:00:00Z"}\n' \
  >"${ARCHIVE_CHANGED}.uploaded.json"
printf '[system]\ntimestamp=changed\n' >"${stem}.meta"
if _icos_cleanup_uploaded_archive "$ARCHIVE_CHANGED"; then
  printf 'error: cleanup accepted a source changed after packaging\n' >&2
  exit 1
fi
[[ -f "$ARCHIVE_CHANGED" ]]
[[ -f "${ARCHIVE_CHANGED}.uploaded.json" ]]
[[ -f "${stem}.jpg" ]]
[[ -f "${stem}.meta" ]]

# A final META without its JPEG blocks creation of that daily product.
incomplete="${QUEUE}/${SITENAME}_2026_10_25_070000.meta"
printf '[system]\ntimestamp=incomplete\n' >"$incomplete"
if icos_package_day 20261025; then
  printf 'error: incomplete pair was packaged\n' >&2
  exit 1
fi
[[ ! -e "${OUTBOX}/IT-Tst_PHEN_20261025_L01_F01.zip" ]]

# Retryable client failures retain the product without blocking it. Permanent
# validation or HTTP 4xx failures create the operator-visible .blocked marker.
FAKE_PYTHON="${TEST_ROOT}/fake-python"
cat >"$FAKE_PYTHON" <<'EOF'
#!/usr/bin/env bash
printf 'simulated client error\n' >&2
exit "${FAKE_CLIENT_RC:?}"
EOF
chmod 0755 "$FAKE_PYTHON"
ICOS_PYTHON="$FAKE_PYTHON"
has_internet() { return 0; }

POLICY_ARCHIVE="${OUTBOX}/IT-Tst_PHEN_20261024_L01_F01.zip"
printf 'archive\n' >"$POLICY_ARCHIVE"
printf '{}\n' >"${POLICY_ARCHIVE}.metadata.json"
: >"${POLICY_ARCHIVE}.manifest"
printf 'staging\n' >"${POLICY_ARCHIVE}.environment"

FAKE_CLIENT_RC=10
export FAKE_CLIENT_RC
icos_upload_outbox
[[ -f "$POLICY_ARCHIVE" ]]
[[ ! -e "${POLICY_ARCHIVE}.blocked" ]]
[[ ! -e "${POLICY_ARCHIVE}.last-error.tmp" ]]

FAKE_CLIENT_RC=20
export FAKE_CLIENT_RC
icos_upload_outbox
[[ -f "$POLICY_ARCHIVE" ]]
[[ -f "${POLICY_ARCHIVE}.blocked" ]]
grep -q 'simulated client error' "${POLICY_ARCHIVE}.blocked"

printf 'ICOS manager tests: OK\n'
