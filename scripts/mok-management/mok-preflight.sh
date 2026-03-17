#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

usage() {
  cat <<'USAGE'
Usage: mok-preflight.sh [--cert <path>] [--der <path>] [--key <path>] [--strict] [--json]

Checks MOK enrollment readiness:
  - Environment prerequisites (UEFI, openssl, mokutil)
  - Certificate/key presence and key permissions
  - Secure Boot state
  - Enrolled/pending MOK status for the selected cert
  - Optional metadata presence under out/keys/mok/*.meta.json

Environment overrides:
  MOK_CERT_PEM    Default cert path (fallback: out/keys/mok/PGMOK.crt)
  MOK_CERT_DER    Default DER path  (fallback: <cert-base>.der)
  MOK_CERT_KEY    Default key path  (fallback: <cert-base>.key)
  MOKUTIL_BIN     mokutil executable name/path (default: mokutil)
  MOK_USE_SUDO    Use sudo for mokutil calls (default: 1)
USAGE
}

CERT_PATH="${MOK_CERT_PEM:-out/keys/mok/PGMOK.crt}"
DER_PATH="${MOK_CERT_DER:-}"
KEY_PATH="${MOK_CERT_KEY:-}"
STRICT="${MOK_STRICT:-0}"
JSON_OUTPUT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --cert)
      CERT_PATH="${2:-}"
      shift 2
      ;;
    --der)
      DER_PATH="${2:-}"
      shift 2
      ;;
    --key)
      KEY_PATH="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --json)
      JSON_OUTPUT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "${DER_PATH}" ]; then
  DER_PATH="${CERT_PATH%.*}.der"
fi
if [ -z "${KEY_PATH}" ]; then
  KEY_PATH="${CERT_PATH%.*}.key"
fi

MOKUTIL_BIN="${MOKUTIL_BIN:-mokutil}"
MOK_USE_SUDO="${MOK_USE_SUDO:-1}"
SUDO_PREFIX=()
SUDO_LIMITED=0
if [ "${MOK_USE_SUDO}" = "1" ] && [ "${EUID}" -ne 0 ]; then
  if sudo -n true 2>/dev/null; then
    SUDO_PREFIX=(sudo -n)
  else
    SUDO_LIMITED=1
  fi
fi

CHECK_NAMES=()
CHECK_STATUS=()
CHECK_DETAIL=()

record_check() {
  CHECK_NAMES+=("$1")
  CHECK_STATUS+=("$2")
  CHECK_DETAIL+=("$3")
}

run_mokutil() {
  "${SUDO_PREFIX[@]}" "${MOKUTIL_BIN}" "$@"
}

to_upper() {
  tr '[:lower:]' '[:upper:]'
}

record_check "repo_root" "PASS" "${REPO_ROOT}"
if [ "${SUDO_LIMITED}" = "1" ]; then
  record_check "sudo_access" "WARN" "Passwordless sudo not available; mokutil queries may be limited"
fi

if [ -d /sys/firmware/efi ]; then
  record_check "uefi" "PASS" "UEFI firmware interface detected"
else
  record_check "uefi" "WARN" "UEFI firmware interface not detected (/sys/firmware/efi missing)"
fi

if command -v openssl >/dev/null 2>&1; then
  record_check "openssl" "PASS" "openssl is available"
else
  record_check "openssl" "FAIL" "openssl is not installed"
fi

if command -v "${MOKUTIL_BIN}" >/dev/null 2>&1; then
  record_check "mokutil" "PASS" "mokutil executable found (${MOKUTIL_BIN})"
else
  record_check "mokutil" "FAIL" "mokutil executable not found (${MOKUTIL_BIN})"
fi

if [ -f "${CERT_PATH}" ]; then
  record_check "cert_file" "PASS" "Certificate file exists: ${CERT_PATH}"
else
  record_check "cert_file" "FAIL" "Certificate file missing: ${CERT_PATH}"
fi

if [ -f "${DER_PATH}" ]; then
  record_check "der_file" "PASS" "DER file exists: ${DER_PATH}"
else
  record_check "der_file" "WARN" "DER file missing (can be generated from cert): ${DER_PATH}"
fi

if [ -f "${KEY_PATH}" ]; then
  record_check "key_file" "PASS" "Key file exists: ${KEY_PATH}"
  perm="$(stat -c '%a' "${KEY_PATH}" 2>/dev/null || stat -f '%Lp' "${KEY_PATH}" 2>/dev/null || echo "")"
  if [ -n "${perm}" ]; then
    mode_octal=$((8#${perm}))
    if (( (mode_octal & 8#077) == 0 )); then
      record_check "key_permissions" "PASS" "Key permissions are private (${perm})"
    else
      record_check "key_permissions" "WARN" "Key permissions are too broad (${perm}); expected owner-only"
    fi
  else
    record_check "key_permissions" "WARN" "Unable to determine key permissions"
  fi
else
  record_check "key_file" "FAIL" "Key file missing: ${KEY_PATH}"
fi

CERT_SHA1=""
if [ -f "${CERT_PATH}" ] && command -v openssl >/dev/null 2>&1; then
  CERT_SHA1="$(openssl x509 -in "${CERT_PATH}" -noout -fingerprint -sha1 2>/dev/null | sed 's/^SHA1 Fingerprint=//' | to_upper || true)"
  if [ -n "${CERT_SHA1}" ]; then
    record_check "cert_fingerprint" "PASS" "SHA1=${CERT_SHA1}"
  else
    record_check "cert_fingerprint" "WARN" "Unable to compute certificate SHA1 fingerprint"
  fi
fi

SB_STATE="unknown"
if command -v "${MOKUTIL_BIN}" >/dev/null 2>&1; then
  if sb_out="$(run_mokutil --sb-state 2>/dev/null)"; then
    if printf '%s\n' "${sb_out}" | grep -qi "enabled"; then
      SB_STATE="enabled"
    elif printf '%s\n' "${sb_out}" | grep -qi "disabled"; then
      SB_STATE="disabled"
    fi
    if [ -n "${sb_out}" ]; then
      record_check "secure_boot_state" "PASS" "${sb_out}"
    else
      record_check "secure_boot_state" "WARN" "mokutil returned an empty secure boot state response"
    fi
  else
    record_check "secure_boot_state" "WARN" "Unable to query secure boot state via mokutil"
  fi
fi

ENROLLED_STATE="unknown"
PENDING_STATE="unknown"
if [ -n "${CERT_SHA1}" ] && command -v "${MOKUTIL_BIN}" >/dev/null 2>&1; then
  if enrolled_out="$(run_mokutil --list-enrolled 2>/dev/null)"; then
    if [ -n "${enrolled_out}" ]; then
      if printf '%s\n' "${enrolled_out}" | to_upper | grep -q "${CERT_SHA1}"; then
        ENROLLED_STATE="yes"
        record_check "enrolled_status" "PASS" "Certificate is enrolled"
      else
        ENROLLED_STATE="no"
        record_check "enrolled_status" "WARN" "Certificate not found in enrolled MOK list"
      fi
    else
      record_check "enrolled_status" "WARN" "Enrolled MOK query returned no output"
    fi
  else
    record_check "enrolled_status" "WARN" "Unable to read enrolled MOK list"
  fi

  if pending_out="$(run_mokutil --list-new 2>/dev/null)"; then
    if [ -n "${pending_out}" ]; then
      if printf '%s\n' "${pending_out}" | to_upper | grep -q "${CERT_SHA1}"; then
        PENDING_STATE="yes"
        record_check "pending_status" "WARN" "Certificate enrollment is pending reboot confirmation"
      else
        PENDING_STATE="no"
        record_check "pending_status" "PASS" "Certificate not present in pending enrollment queue"
      fi
    else
      PENDING_STATE="no"
      record_check "pending_status" "PASS" "No pending MOK enrollments reported"
    fi
  else
    record_check "pending_status" "WARN" "Unable to query pending MOK enrollments"
  fi
fi

CERT_BASE="$(basename "${CERT_PATH}")"
CERT_NAME="${CERT_BASE%.*}"
META_PATH="out/keys/mok/${CERT_NAME}.meta.json"
if [ -f "${META_PATH}" ]; then
  record_check "metadata_file" "PASS" "Metadata file present: ${META_PATH}"
else
  record_check "metadata_file" "WARN" "Metadata file missing: ${META_PATH}"
fi

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
for status in "${CHECK_STATUS[@]}"; do
  case "${status}" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac
done

READY_TO_ENROLL=0
READY_FOR_SIGNING=0
if [ "${FAIL_COUNT}" -eq 0 ] && [ "${SB_STATE}" != "unknown" ]; then
  READY_TO_ENROLL=1
fi
if [ "${ENROLLED_STATE}" = "yes" ] && [ "${FAIL_COUNT}" -eq 0 ]; then
  READY_FOR_SIGNING=1
fi

if [ "${JSON_OUTPUT}" = "1" ]; then
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: --json output requires python3" >&2
    exit 2
  fi
  checks_tsv=""
  for i in "${!CHECK_NAMES[@]}"; do
    checks_tsv+="${CHECK_NAMES[$i]}"$'\t'"${CHECK_STATUS[$i]}"$'\t'"${CHECK_DETAIL[$i]}"$'\n'
  done
  export checks_tsv CERT_PATH DER_PATH KEY_PATH META_PATH CERT_SHA1
  export PASS_COUNT WARN_COUNT FAIL_COUNT SB_STATE ENROLLED_STATE PENDING_STATE
  export READY_TO_ENROLL READY_FOR_SIGNING
  python3 - <<'PY'
import json
import os

checks = []
for line in os.environ.get("checks_tsv", "").splitlines():
    if not line:
        continue
    name, status, detail = (line.split("\t", 2) + ["", "", ""])[:3]
    checks.append({"name": name, "status": status, "detail": detail})

payload = {
    "cert_path": os.environ.get("CERT_PATH", ""),
    "der_path": os.environ.get("DER_PATH", ""),
    "key_path": os.environ.get("KEY_PATH", ""),
    "meta_path": os.environ.get("META_PATH", ""),
    "cert_sha1": os.environ.get("CERT_SHA1", ""),
    "summary": {
        "pass": int(os.environ.get("PASS_COUNT", "0")),
        "warn": int(os.environ.get("WARN_COUNT", "0")),
        "fail": int(os.environ.get("FAIL_COUNT", "0")),
        "secure_boot_state": os.environ.get("SB_STATE", "unknown"),
        "enrolled_state": os.environ.get("ENROLLED_STATE", "unknown"),
        "pending_state": os.environ.get("PENDING_STATE", "unknown"),
        "ready_to_enroll": os.environ.get("READY_TO_ENROLL", "0") == "1",
        "ready_for_signing": os.environ.get("READY_FOR_SIGNING", "0") == "1",
    },
    "checks": checks,
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY
else
  echo "MOK preflight report"
  echo "===================="
  echo "Certificate : ${CERT_PATH}"
  echo "DER         : ${DER_PATH}"
  echo "Key         : ${KEY_PATH}"
  echo "Metadata    : ${META_PATH}"
  [ -n "${CERT_SHA1}" ] && echo "SHA1        : ${CERT_SHA1}"
  echo
  printf "%-20s %-6s %s\n" "CHECK" "STATE" "DETAIL"
  printf "%-20s %-6s %s\n" "-----" "-----" "------"
  for i in "${!CHECK_NAMES[@]}"; do
    printf "%-20s %-6s %s\n" "${CHECK_NAMES[$i]}" "${CHECK_STATUS[$i]}" "${CHECK_DETAIL[$i]}"
  done
  echo
  echo "Summary: PASS=${PASS_COUNT} WARN=${WARN_COUNT} FAIL=${FAIL_COUNT}"
  echo "Secure Boot state : ${SB_STATE}"
  echo "Enrolled state    : ${ENROLLED_STATE}"
  echo "Pending state     : ${PENDING_STATE}"
  echo "Ready to enroll   : ${READY_TO_ENROLL}"
  echo "Ready for signing : ${READY_FOR_SIGNING}"
fi

if [ "${FAIL_COUNT}" -gt 0 ]; then
  exit 1
fi
if [ "${STRICT}" = "1" ] && [ "${WARN_COUNT}" -gt 0 ]; then
  exit 1
fi

exit 0
