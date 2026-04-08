#!/usr/bin/env bash
# Description: Validate component layout and scan for unfinished markers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi

cd "${PROJECT_ROOT}"

OUT_DIR="out/maintenance"
mkdir -p "${OUT_DIR}"
REPORT="${OUT_DIR}/maint-audit.txt"

{
    echo "PhoenixBoot Maintenance Audit"
    echo "============================="
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
} > "${REPORT}"

echo "[1/3] Running component layout check..."
if bash scripts/testing/test-component-layout.sh >> "${REPORT}" 2>&1; then
    echo "layout_check=pass" >> "${REPORT}"
else
    echo "layout_check=fail" >> "${REPORT}"
fi

echo "[2/3] Running tree audit..."
bash scripts/maintenance/audit-tree.sh >> "${REPORT}" 2>&1 || true

echo "[3/3] Scanning for unfinished markers..."
unfinished_files="$(rg -l "TODO|STUB|FIXME|TBD|XXX" . || true)"
if [ -n "${unfinished_files}" ]; then
    {
        echo ""
        echo "unfinished_markers=found"
        echo "${unfinished_files}"
    } >> "${REPORT}"
else
    echo "unfinished_markers=none" >> "${REPORT}"
fi

echo "Maintenance audit written to ${REPORT}"
