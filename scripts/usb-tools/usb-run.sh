#!/usr/bin/env bash
# Description: Creates a bootable USB drive with the production ESP.

set -euo pipefail

[ -n "${USB1_DEV:-}" ] || { echo "☠ USB1_DEV=/dev/sdX is required"; exit 1; }

# Build artifacts and package ESP
./pf.py build-build build-package-esp

# Normalize ESP for Secure Boot (best-effort)
./pf.py valid-esp-secure || echo "ℹ☠ Skipping ESP secure normalization"
./pf.py verify-esp-robust

# Write to USB
bash scripts/usb-tools/usb-prepare.sh

# Sanitize USB
USB_FORCE=1 ./pf.py usb-sanitize || echo "ℹ☠ Skipping USB sanitization"

echo "☠ USB prepared on ${USB1_DEV} — select it in firmware boot menu"

