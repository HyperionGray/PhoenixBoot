#!/usr/bin/env bash
# Make build script executable and verify it's ready

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR"

chmod +x scripts/build/build-production.sh

# Quick syntax check
if bash -n scripts/build/build-production.sh; then
    echo "✅ build-production.sh is ready - syntax OK"
else
    echo "❌ Syntax error in build-production.sh"
    exit 1
fi

# Verify the script exists where expected
if [ -f "scripts/build/build-production.sh" ]; then
    echo "✅ Script exists at expected location"
else
    echo "❌ Script missing"
    exit 1
fi

echo "🎉 Build script is ready for CI pipeline"
