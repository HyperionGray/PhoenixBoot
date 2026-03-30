#!/usr/bin/env bash
# Clean build artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

echo "🧹 Cleaning build artifacts..."

# Always clean these
rm -rf out/staging/* out/qemu/* out/lint/* 2>/dev/null || true

# Remove common generated recovery/inventory artifacts from repo root
rm -f \
  bootkit_scan_results.json \
  bootkit_scan_prereboot.json \
  hardware_recovery_results.json \
  cert_inventory_*.json \
  2>/dev/null || true

# Remove transient helper mount dirs if left behind
sudo rmdir /tmp/phoenixguard_recovery_mount 2>/dev/null || true
sudo rmdir /tmp/phoenixguard_squash_mount 2>/dev/null || true

# Deep clean ESP if requested
if [ "${DEEP_CLEAN:-0}" = "1" ]; then
    echo "🗑️  Deep clean: removing ESP artifacts..."
    rm -rf out/esp/* 2>/dev/null || true
fi

echo "✅ Cleanup complete"
