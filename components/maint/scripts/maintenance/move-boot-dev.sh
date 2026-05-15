#!/usr/bin/env bash
# Description: Move hardware boot development code to experimental/ tree.
#
# This is a one-shot migration helper. The bulk of the work was done during
# the alpha cleanup (see ALPHA_RELEASE_PLAN.md); the experimental tree now
# lives at experimental/. This script remains as a safety net in case anyone
# re-creates the old dev/ layout.

set -euo pipefail

DEST="experimental/firmware-recovery-dev"

[ -d scripts ] && {
    mkdir -p "${DEST}"
    for script in scripts/hardware*.py scripts/*flashrom* scripts/*firmware* scripts/fix-*; do
        [ -f "$script" ] && mv "$script" "${DEST}/" 2>/dev/null || true
    done
}

[ -d hardware_database ] && mv hardware_database experimental/hardware-database
[ -d scraped_hardware ] && mv scraped_hardware experimental/scraped-hardware

echo "Hardware boot development code moved to experimental/"
