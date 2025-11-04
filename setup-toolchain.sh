#!/usr/bin/env bash
set -euo pipefail

# Bootstrap PhoenixBoot toolchain and environment
# This script checks and sets up all necessary tools and dependencies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Bootstrapping PhoenixBoot toolchain..."
exec bash "${SCRIPT_DIR}/scripts/toolchain-check.sh"
