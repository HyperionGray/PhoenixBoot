#!/usr/bin/env bash
# Description: Audits repository structure and hygiene findings.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${PROJECT_ROOT}/out/audit"
REPORT_JSON="${OUT_DIR}/report.json"
SUMMARY_TXT="${OUT_DIR}/summary.txt"

CLEANUP_STRAY=0
FAIL_ON_FINDINGS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cleanup-stray)
            CLEANUP_STRAY=1
            ;;
        --fail-on-findings)
            FAIL_ON_FINDINGS=1
            ;;
        -h|--help)
            cat <<'USAGE'
Usage: scripts/maintenance/audit-tree.sh [--cleanup-stray] [--fail-on-findings]

Options:
  --cleanup-stray      Remove known runtime residue files if found.
  --fail-on-findings   Exit non-zero when stale files or unfinished markers are detected.
USAGE
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

mkdir -p "${OUT_DIR}"
echo "PhoenixGuard Repository Audit Summary" > "${SUMMARY_TXT}"
echo "===================================" >> "${SUMMARY_TXT}"
echo "" >> "${SUMMARY_TXT}"

STAGING_COUNT=0
DEV_COUNT=0
WIP_COUNT=0
DEMO_COUNT=0

mapfile -t FILES < <(
    cd "${PROJECT_ROOT}" &&
    rg --files --hidden -g '!.git/*' -g '!out/**'
)

for file in "${FILES[@]}"; do
    case "$file" in
        *demo*|*example*|*sample*|*sandbox*|*mock*|*test-*|*bak/*|*legacy-old*)
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
done

TOTAL_COUNT=$((STAGING_COUNT + DEV_COUNT + WIP_COUNT + DEMO_COUNT))

STALE_CANDIDATES=(
    "defaultNetworkBackend"
    "storage.lock"
    "userns.lock"
    "db.sql"
    "issues.txt"
    "overlay/.has-mount-program"
    "overlay-containers/containers.lock"
    "overlay-images/images.lock"
    "overlay-layers/layers.lock"
)

FOUND_STALE=()
for path in "${STALE_CANDIDATES[@]}"; do
    if [[ -e "${PROJECT_ROOT}/${path}" ]]; then
        FOUND_STALE+=("${path}")
    fi
done

TODO_FINDINGS=()
while IFS= read -r line; do
    TODO_FINDINGS+=("${line}")
done < <(
    cd "${PROJECT_ROOT}" &&
    rg -n '^\s*#.*\b(TODO|STUB|FIXME|TBD)\b' scripts utils *.pf 2>/dev/null || true
)

CLEANED_ITEMS=()
if [[ "${CLEANUP_STRAY}" -eq 1 && "${#FOUND_STALE[@]}" -gt 0 ]]; then
    for path in "${FOUND_STALE[@]}"; do
        rm -f "${PROJECT_ROOT}/${path}"
        CLEANED_ITEMS+=("${path}")
    done

    for maybe_empty_dir in overlay overlay-containers overlay-images overlay-layers; do
        if rmdir "${PROJECT_ROOT}/${maybe_empty_dir}" 2>/dev/null; then
            CLEANED_ITEMS+=("${maybe_empty_dir}/")
        fi
    done
fi

# Recompute stale list after optional cleanup
FOUND_STALE=()
for path in "${STALE_CANDIDATES[@]}"; do
    if [[ -e "${PROJECT_ROOT}/${path}" ]]; then
        FOUND_STALE+=("${path}")
    fi
done

echo "TOTAL: $TOTAL_COUNT files" >> "${SUMMARY_TXT}"
echo "STAGING: $STAGING_COUNT files" >> "${SUMMARY_TXT}"
echo "DEV: $DEV_COUNT files" >> "${SUMMARY_TXT}"
echo "WIP: $WIP_COUNT files" >> "${SUMMARY_TXT}"
echo "DEMO: $DEMO_COUNT files" >> "${SUMMARY_TXT}"
echo "" >> "${SUMMARY_TXT}"
echo "UNFINISHED_MARKERS: ${#TODO_FINDINGS[@]}" >> "${SUMMARY_TXT}"
echo "STALE_ARTIFACTS: ${#FOUND_STALE[@]}" >> "${SUMMARY_TXT}"

if [[ "${#FOUND_STALE[@]}" -gt 0 ]]; then
    echo "" >> "${SUMMARY_TXT}"
    echo "Stale artifacts still present:" >> "${SUMMARY_TXT}"
    for path in "${FOUND_STALE[@]}"; do
        echo "  - ${path}" >> "${SUMMARY_TXT}"
    done
fi

if [[ "${#CLEANED_ITEMS[@]}" -gt 0 ]]; then
    echo "" >> "${SUMMARY_TXT}"
    echo "Cleaned artifacts:" >> "${SUMMARY_TXT}"
    for path in "${CLEANED_ITEMS[@]}"; do
        echo "  - ${path}" >> "${SUMMARY_TXT}"
    done
fi

if [[ "${#TODO_FINDINGS[@]}" -gt 0 ]]; then
    echo "" >> "${SUMMARY_TXT}"
    echo "Unfinished marker hits (scripts/utils/*.pf):" >> "${SUMMARY_TXT}"
    for line in "${TODO_FINDINGS[@]}"; do
        echo "  - ${line}" >> "${SUMMARY_TXT}"
    done
fi

TMP_STALE="$(mktemp)"
TMP_TODO="$(mktemp)"
TMP_CLEANED="$(mktemp)"
printf '%s\n' "${FOUND_STALE[@]}" > "${TMP_STALE}"
printf '%s\n' "${TODO_FINDINGS[@]}" > "${TMP_TODO}"
printf '%s\n' "${CLEANED_ITEMS[@]}" > "${TMP_CLEANED}"

python3 - "${REPORT_JSON}" "${STAGING_COUNT}" "${DEV_COUNT}" "${WIP_COUNT}" "${DEMO_COUNT}" "${TOTAL_COUNT}" "${TMP_STALE}" "${TMP_TODO}" "${TMP_CLEANED}" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

report_path = Path(sys.argv[1])
staging = int(sys.argv[2])
dev = int(sys.argv[3])
wip = int(sys.argv[4])
demo = int(sys.argv[5])
total = int(sys.argv[6])
stale_path = Path(sys.argv[7])
todo_path = Path(sys.argv[8])
cleaned_path = Path(sys.argv[9])

def lines(path: Path):
    return [line for line in path.read_text().splitlines() if line.strip()]

report = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "counts": {
        "total": total,
        "staging": staging,
        "dev": dev,
        "wip": wip,
        "demo": demo,
    },
    "stale_artifacts": lines(stale_path),
    "unfinished_markers": lines(todo_path),
    "cleaned_artifacts": lines(cleaned_path),
}

report_path.write_text(json.dumps(report, indent=2) + "\n")
PY

rm -f "${TMP_STALE}" "${TMP_TODO}" "${TMP_CLEANED}"

echo "☠ Audit complete - see out/audit/"

if [[ "${FAIL_ON_FINDINGS}" -eq 1 ]] && { [[ "${#FOUND_STALE[@]}" -gt 0 ]] || [[ "${#TODO_FINDINGS[@]}" -gt 0 ]]; }; then
    exit 1
fi

