#!/usr/bin/env bash
# Clean build artifacts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi

cd "${PROJECT_ROOT}"

echo "Cleaning build artifacts..."

# Always clean these
rm -rf out/staging/* out/qemu/* out/lint/* out/audit/* out/maintenance/* 2>/dev/null || true

# Deep clean ESP if requested
if [ "${DEEP_CLEAN:-0}" = "1" ]; then
    echo "Deep clean: removing ESP artifacts..."
    rm -rf out/esp/* 2>/dev/null || true
fi

echo "Cleanup complete"
