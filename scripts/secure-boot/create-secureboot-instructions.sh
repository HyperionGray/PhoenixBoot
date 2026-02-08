#!/usr/bin/env bash
# Description: Create comprehensive secure boot instructions for CD/ISO

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

DOCS_DIR_DEFAULT="out/artifacts/docs"
DOCS_DIR="$DOCS_DIR_DEFAULT"

usage() {
  cat <<EOF
Usage: $0 [--docs-dir DIR]

Options:
  --docs-dir DIR   override where instructions and checksums are written (default: $DOCS_DIR_DEFAULT)
  -h, --help       show this message
EOF
}

die() {
  echo "☠ $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --docs-dir)
      if [ $# -lt 2 ]; then
        die "--docs-dir requires a directory argument"
      fi
      DOCS_DIR="${2:-}"
      shift 2
      ;;
    --docs-dir=*)
      DOCS_DIR="${1#*=}"
      shift
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

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
ESP_SEARCH_DIRS=(out/artifacts/esp out/esp)
ESP_SOURCE_DIR=""
for cand in "${ESP_SEARCH_DIRS[@]}"; do
    if [ -f "$cand/esp.img" ]; then
        ESP_SOURCE_DIR="$cand"
        break
    fi
done

if [ -n "$ESP_SOURCE_DIR" ]; then
    echo "Calculating checksums from $ESP_SOURCE_DIR..."
    (
        cd "$ESP_SOURCE_DIR" || exit 1
        sha256sum esp.img *.efi 2>/dev/null || true
    ) >> "$DOCS_DIR/CHECKSUMS.txt"
else
    echo "WARNING: No ESP artifacts found in ${ESP_SEARCH_DIRS[*]} for checksum generation" >> "$DOCS_DIR/CHECKSUMS.txt"
fi

echo "✅ Secure boot instructions created in $DOCS_DIR"
