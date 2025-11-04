#!/usr/bin/env bash
# Description: Unenrolls the PhoenixGuard MOK certificate.

set -euo pipefail

MOK_CERT_DER=$1

echo "☠  PhoenixGuard MOK Certificate Removal"
echo "======================================="
echo

if [ ! -f "$MOK_CERT_DER" ]; then
    echo "☠ ERROR: DER certificate not found: $MOK_CERT_DER"
    exit 1
fi
if ! command -v mokutil >/dev/null 2>&1; then
    echo "☠ ERROR: mokutil not found."
    exit 1
fi

CERT_SHA1=$(openssl x509 -inform DER -in "$MOK_CERT_DER" -noout -fingerprint -sha1 | sed 's/^SHA1 Fingerprint=//')

if ! sudo mokutil --list-enrolled 2>/dev/null | grep -q "$CERT_SHA1"; then
    echo "ℹ☠  Certificate is not currently enrolled."
    exit 0
fi

read -p "Continue with MOK removal? [y/N]: " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo
echo "☠  Staging MOK certificate for removal..."
sudo -v

if ! sudo mokutil --delete "$MOK_CERT_DER"; then
    echo "☠ ERROR: mokutil delete failed."
    exit 1
fi

echo
echo "☠ MOK certificate removal staged."
echo
echo "☠ REBOOT REQUIRED - Complete Removal Process"

