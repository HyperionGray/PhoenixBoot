#!/usr/bin/env bash
# Description: Enrolls the PhoenixGuard MOK certificate.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

MOK_CERT_PEM=out/keys/mok/PGMOK.crt
MOK_CERT_DER=out/keys/mok/PGMOK.der
MOK_DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [--cert-pem PATH] [--cert-der PATH] [--dry-run]

Options:
  --cert-pem PATH  path to PEM certificate (default: ${MOK_CERT_PEM})
  --cert-der PATH  path to DER certificate output (default: ${MOK_CERT_DER})
  --dry-run        write metadata only without calling mokutil (defaults to ${MOK_DRY_RUN})
  -h, --help       show this help message
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --cert-pem)
      if [ $# -lt 2 ]; then
        echo "☠ --cert-pem requires an argument"
        usage
      fi
      MOK_CERT_PEM="$2"
      shift 2
      ;;
    --cert-pem=*)
      MOK_CERT_PEM="${1#*=}"
      shift
      ;;
    --cert-der)
      if [ $# -lt 2 ]; then
        echo "☠ --cert-der requires an argument"
        usage
      fi
      MOK_CERT_DER="$2"
      shift 2
      ;;
    --cert-der=*)
      MOK_CERT_DER="${1#*=}"
      shift
      ;;
    --dry-run)
      MOK_DRY_RUN="1"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "☠ Unknown option: $1"
      usage
      ;;
  esac
done

echo "☠ PhoenixGuard MOK Certificate Enrollment"
echo "==========================================="
echo

# Preflight checks
if [ ! -d /sys/firmware/efi ]; then
    echo "☠ ERROR: UEFI firmware not detected."
    exit 1
fi

# Ensure centralized directories exist for outputs
mkdir -p out/keys/mok out/keys/secure_boot
if [ -f /run/.containerenv ] || [ -f /.dockerenv ] || grep -qiE "(lxc|container)" /proc/1/environ 2>/dev/null; then
    echo "☠ ERROR: Detected containerized environment."
    exit 1
fi
if ! command -v mokutil >/dev/null 2>&1; then
    echo "☠ ERROR: mokutil not found."
    exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
    echo "☠ ERROR: openssl not found."
    exit 1
fi
if [ ! -f "$MOK_CERT_PEM" ]; then
    echo "☠ ERROR: MOK PEM certificate not found: $MOK_CERT_PEM"
    exit 1
fi

mkdir -p "$(dirname "$MOK_CERT_DER")"

echo "--- Current Secure Boot State ---"
sudo mokutil --sb-state || true
echo

# Certificate analysis
CERT_SHA1=$(openssl x509 -in "$MOK_CERT_PEM" -noout -fingerprint -sha1 | sed 's/^SHA1 Fingerprint=//')
if sudo mokutil --list-enrolled 2>/dev/null | grep -q "$CERT_SHA1"; then
    echo "☠ MOK certificate already enrolled."
    exit 0
fi

# PEM to DER conversion
openssl x509 -in "$MOK_CERT_PEM" -outform DER -out "$MOK_CERT_DER"

# Prepare metadata (subject/issuer/dates/fingerprints)
SUBJECT=$(openssl x509 -in "$MOK_CERT_PEM" -noout -subject | sed 's/^subject= //')
ISSUER=$(openssl x509 -in "$MOK_CERT_PEM" -noout -issuer | sed 's/^issuer= //')
DATES=$(openssl x509 -in "$MOK_CERT_PEM" -noout -dates | tr '\n' ' ')
SHA1_FP=$(openssl x509 -in "$MOK_CERT_PEM" -noout -fingerprint -sha1 | sed 's/^SHA1 Fingerprint=//')
SHA256_FP=$(openssl x509 -in "$MOK_CERT_PEM" -noout -fingerprint -sha256 | sed 's/^SHA256 Fingerprint=//')
NAME_BASE=$(basename "$MOK_CERT_PEM")
NAME_NOEXT="${NAME_BASE%.*}"
META_DIR="out/keys/mok"
META_PATH="$META_DIR/${NAME_NOEXT}.meta.json"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$MOK_DRY_RUN" = "1" ]; then
    echo "☠ DRY RUN MODE (MOK_DRY_RUN=1)"
    # Write metadata with pending=true but do not import
    mkdir -p "$META_DIR"
    cat > "$META_PATH" <<JSON
{
  "subject": "$SUBJECT",
  "issuer": "$ISSUER",
  "validity": "$DATES",
  "sha1": "$SHA1_FP",
  "sha256": "$SHA256_FP",
  "created_utc": "$NOW",
  "paths": {"pem": "${MOK_CERT_PEM}", "der": "${MOK_CERT_DER}", "key": "${MOK_CERT_PEM%.*}.key"},
  "imported_at_utc": null,
  "pending": true
}
JSON
    exit 0
fi

echo "--- MOK Enrollment Process ---"
echo "About to import the MOK certificate for enrollment using mokutil."
echo

sudo -v
echo "☠ Importing MOK certificate..."

if ! sudo mokutil --import "$MOK_CERT_DER"; then
    echo "☠ ERROR: mokutil import failed."
    exit 1
fi

# Persist metadata with pending=true
mkdir -p "$META_DIR"
cat > "$META_PATH" <<JSON
{
  "subject": "$SUBJECT",
  "issuer": "$ISSUER",
  "validity": "$DATES",
  "sha1": "$SHA1_FP",
  "sha256": "$SHA256_FP",
  "created_utc": "$NOW",
  "paths": {"pem": "${MOK_CERT_PEM}", "der": "${MOK_CERT_DER}", "key": "${MOK_CERT_PEM%.*}.key"},
  "imported_at_utc": "$NOW",
  "pending": true
}
JSON

echo
echo "☠ MOK certificate import successful!"
echo
echo "--- Pending MOK Enrollments ---"
sudo mokutil --list-new 2>/dev/null || echo "(Unable to list pending enrollments)"
echo
echo "☠ REBOOT REQUIRED - Complete Enrollment Process"
