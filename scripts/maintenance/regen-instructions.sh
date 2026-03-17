#!/usr/bin/env bash
# Description: Regenerates the copilot-instructions.md file from its components.

set -euo pipefail

# Ensure all component files exist
[ -f WARP.md ] || echo "[WARP.md missing – add strategic context]" > WARP.md
[ -f PROJECT.txt ] || echo "[PROJECT.txt missing – add high-level summary]" > PROJECT.txt
[ -f CHANGES ] || touch CHANGES
[ -f TODO ] || echo -e "TODO-001: Extend production boot features\nDONE-002: Probe hardware compatibility bugs (implemented via scripts/recovery/hardware_compat_probe.py)\nDONE-003: Add secure boot capability (implemented across secure.pf and scripts/secure-boot/)" > TODO
[ -f IDEAS ] || touch IDEAS
[ -f HOTSPOTS ] || touch HOTSPOTS

# Concatenate in required order
{
    echo "# WARP"
    echo ""
    cat WARP.md
    echo ""
    echo "# PROJECT"
    echo ""
    cat PROJECT.txt
    echo ""
    echo "# CHANGES"
    echo ""
    cat CHANGES
    echo ""
    echo "# TODO"
    echo ""
    cat TODO
    echo ""
    echo "# IDEAS"
    echo ""
    cat IDEAS
    echo ""
    echo "# HOTSPOTS"
    echo ""
    cat HOTSPOTS
} > copilot-instructions.md

echo "☠ Generated copilot-instructions.md"

