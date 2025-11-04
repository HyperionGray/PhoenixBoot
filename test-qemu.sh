#!/usr/bin/env bash
set -euo pipefail

# Run QEMU tests for PhoenixBoot
# Tests bootable ESP image in a virtual machine

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Running QEMU boot test..."
exec bash "${SCRIPT_DIR}/scripts/qemu-test.sh"
