#!/usr/bin/env bash
# Description: Audits repository structure, unfinished markers, and stale artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPO_ROOT="$(cd "${COMPONENT_ROOT}/../.." && pwd)"

cd "${REPO_ROOT}"

mkdir -p out/audit

CLASSIFICATION_REPORT="out/audit/classification.txt"
TODO_REPORT="out/audit/unfinished-markers.txt"
STALE_REPORT="out/audit/stale-paths.txt"
JSON_REPORT="out/audit/report.json"
SUMMARY_REPORT="out/audit/summary.txt"

STAGING_COUNT=0
DEV_COUNT=0
WIP_COUNT=0
DEMO_COUNT=0

while IFS= read -r file; do
    case "$file" in
        out/*|.git/*)
            ;;
        *demo*|*example*|*sample*|*sandbox*|*mock*|*test-*|*bak/*)
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
done < <(git ls-files)

{
    echo "PhoenixBoot Repository Audit Summary"
    echo "==================================="
    echo
    echo "File Classification (tracked files):"
    echo "  STAGING: ${STAGING_COUNT}"
    echo "  DEV:     ${DEV_COUNT}"
    echo "  WIP:     ${WIP_COUNT}"
    echo "  DEMO:    ${DEMO_COUNT}"
    echo
} > "${SUMMARY_REPORT}"

{
    echo "File Classification"
    echo "==================="
    echo "STAGING=${STAGING_COUNT}"
    echo "DEV=${DEV_COUNT}"
    echo "WIP=${WIP_COUNT}"
    echo "DEMO=${DEMO_COUNT}"
} > "${CLASSIFICATION_REPORT}"

rg --hidden -n --glob '!out/**' --glob '!\.git/**' \
    '(TODO|FIXME|STUB|TBD|WIP|UNFINISHED|NotImplementedError)' \
    . > "${TODO_REPORT}" || true

{
    echo "Potentially stale/generated tracked paths"
    echo "========================================="
    git ls-files | rg '(^|/)(target|dist|build)/|(\.log$)|(^|/)tmp/' || true
} > "${STALE_REPORT}"

TODO_COUNT=0
if [ -s "${TODO_REPORT}" ]; then
    TODO_COUNT="$(wc -l < "${TODO_REPORT}" | tr -d ' ')"
fi

STALE_COUNT=0
if [ -s "${STALE_REPORT}" ]; then
    STALE_COUNT="$(tail -n +3 "${STALE_REPORT}" | wc -l | tr -d ' ')"
fi

{
    echo "Unfinished markers detected: ${TODO_COUNT}"
    echo "Potential stale/generated tracked paths: ${STALE_COUNT}"
    echo
    echo "Detailed reports:"
    echo "  - ${CLASSIFICATION_REPORT}"
    echo "  - ${TODO_REPORT}"
    echo "  - ${STALE_REPORT}"
} >> "${SUMMARY_REPORT}"

cat > "${JSON_REPORT}" <<JSON
{
  "classification": {
    "staging": ${STAGING_COUNT},
    "dev": ${DEV_COUNT},
    "wip": ${WIP_COUNT},
    "demo": ${DEMO_COUNT}
  },
  "unfinished_markers_count": ${TODO_COUNT},
  "stale_paths_count": ${STALE_COUNT},
  "reports": {
    "summary": "${SUMMARY_REPORT}",
    "classification": "${CLASSIFICATION_REPORT}",
    "unfinished_markers": "${TODO_REPORT}",
    "stale_paths": "${STALE_REPORT}"
  }
}
JSON

echo "☠ Audit complete - see out/audit/"

