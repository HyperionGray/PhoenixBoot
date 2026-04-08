#!/usr/bin/env bash
# Description: Audits repository layout and categorizes files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi

cd "${PROJECT_ROOT}"

OUT_DIR="out/audit"
mkdir -p "${OUT_DIR}"
SUMMARY_FILE="${OUT_DIR}/summary.txt"
REPORT_FILE="${OUT_DIR}/report.json"

STAGING_COUNT=0
DEV_COUNT=0
WIP_COUNT=0
DEMO_COUNT=0
TOTAL_FILES=0

while IFS= read -r file; do
    [ -f "$file" ] || continue
    TOTAL_FILES=$((TOTAL_FILES + 1))
    case "$file" in
        *demo*|*example*|*sample*|*sandbox*|*mock*|*bak/*)
            DEMO_COUNT=$((DEMO_COUNT + 1))
            ;;
        *wip*|*proto*|*experimental*|*universal_bios*|*universal-bios*)
            WIP_COUNT=$((WIP_COUNT + 1))
            ;;
        *bringup*|*platform*|*board*|*hardware_*|*flashrom*|*bootstrap*)
            DEV_COUNT=$((DEV_COUNT + 1))
            ;;
        *)
            STAGING_COUNT=$((STAGING_COUNT + 1))
            ;;
    esac
done < <(git ls-files && git ls-files --others --exclude-standard)

{
    echo "PhoenixBoot Repository Audit Summary"
    echo "==================================="
    echo ""
    echo "Total files scanned: ${TOTAL_FILES}"
    echo "STAGING: ${STAGING_COUNT} files"
    echo "DEV: ${DEV_COUNT} files"
    echo "WIP: ${WIP_COUNT} files"
    echo "DEMO: ${DEMO_COUNT} files"
    echo ""
    echo "Notes:"
    echo "- This report is heuristic and path-based."
    echo "- Use with test-component-layout.sh for structure validation."
} > "${SUMMARY_FILE}"

cat > "${REPORT_FILE}" <<EOF
{
  "total_files": ${TOTAL_FILES},
  "staging": ${STAGING_COUNT},
  "dev": ${DEV_COUNT},
  "wip": ${WIP_COUNT},
  "demo": ${DEMO_COUNT}
}
EOF

echo "Audit complete - see ${OUT_DIR}/"

