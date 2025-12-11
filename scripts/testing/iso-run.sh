#!/usr/bin/env bash
# Description: Prepares an ESP with an ISO and boots it in QEMU.

set -euo pipefail

[ -n "${ISO_PATH:-}" ] || { echo "☠ ISO_PATH=/path.iso is required"; exit 1; }

# Setup toolchain and build artifacts
./pf.py build-setup build-build

# Build an ESP containing the ISO
ISO_PATH="${ISO_PATH}" ./pf.py build-package-esp-iso

# Ensure Secure Boot shim is the default BOOTX64
./pf.py valid-esp-secure

# Verify and boot in QEMU (headless)
./pf.py verify-esp-robust
./pf.py test-qemu

echo "☠ ISO run completed"

