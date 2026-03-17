#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

TEST_BASE="out/keys/mok/TEST_MOK_JSON"
TEST_CERT="${TEST_BASE}.crt"
TEST_KEY="${TEST_BASE}.key"
TEST_DER="${TEST_BASE}.der"

cleanup() {
  rm -f "$TEST_CERT" "$TEST_KEY" "$TEST_DER"
}
trap cleanup EXIT

mkdir -p "out/keys/mok"

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TEST_KEY" \
  -out "$TEST_CERT" \
  -days 1 \
  -subj "/CN=PhoenixBoot MOK JSON Test" >/dev/null 2>&1
openssl x509 -in "$TEST_CERT" -outform DER -out "$TEST_DER"

json_output="$(bash scripts/mok-management/mok-list-keys.sh --json --skip-enrollment-check)"

printf '%s' "$json_output" | python3 - "$TEST_CERT" "$TEST_KEY" <<'PY'
import json
import sys

cert_path = sys.argv[1]
key_path = sys.argv[2]
data = json.load(sys.stdin)

if data.get("enrollment_check") != "skipped":
    raise SystemExit("expected enrollment_check=skipped")

certificates = data.get("certificates", [])
if not isinstance(certificates, list):
    raise SystemExit("certificates field is not a list")

matches = [item for item in certificates if item.get("path") == cert_path]
if not matches:
    raise SystemExit(f"missing expected cert entry: {cert_path}")

entry = matches[0]
if entry.get("has_private_key") is not True:
    raise SystemExit("expected has_private_key=true for test cert")
if entry.get("private_key_path") != key_path:
    raise SystemExit("private_key_path did not match generated key")
if not entry.get("sha1"):
    raise SystemExit("sha1 fingerprint missing")

summary = data.get("summary", {})
if summary.get("total", 0) < 1:
    raise SystemExit("summary.total should be >= 1")
PY

echo "PASS: MOK inventory JSON output is valid"
