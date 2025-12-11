#!/usr/bin/env bash
# Description: Create comprehensive secure boot instructions for CD/ISO

set -euo pipefail

DOCS_DIR="${DOCS_DIR:-out/artifacts/docs}"
mkdir -p "$DOCS_DIR"

cat > "$DOCS_DIR/README_CD.txt" << 'EOF'
================================================================
   PhoenixGuard Secure Boot CD - Quick Start Guide
================================================================

CONTENTS OF THIS CD:
  /boot/esp.img          - Bootable ESP image
  /efi/*.efi             - UEFI binaries (NuclearBoot, UUEFI, KeyEnroll)
  /keys/                 - Secure Boot keys (PK, KEK, db, MOK)
  /docs/                 - Detailed documentation

QUICK START:
1. Boot from this CD
2. Select boot option in firmware menu
3. For Secure Boot: Run KeyEnrollEdk2.efi to enroll custom keys
4. Reboot and enable Secure Boot in firmware settings

DETAILED INSTRUCTIONS:
See /docs/SECURE_BOOT_SETUP.md for comprehensive setup guide

SUPPORT:
GitHub: https://github.com/P4X-ng/PhoenixBoot
Docs: docs/ directory in repository

================================================================
EOF

cat > "$DOCS_DIR/CHECKSUMS.txt" << 'EOF'
# PhoenixGuard Artifact Checksums
# Verify these after writing to media

EOF

# Calculate checksums if files exist
if [ -f out/artifacts/esp/esp.img ]; then
    echo "Calculating checksums..."
    (
        cd out/artifacts/esp || exit 1
        sha256sum esp.img *.efi 2>/dev/null || true
    ) >> "$DOCS_DIR/CHECKSUMS.txt"
fi

echo "✅ Secure boot instructions created in $DOCS_DIR"
