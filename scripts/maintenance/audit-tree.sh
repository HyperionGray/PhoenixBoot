#!/usr/bin/env bash
# Description: Audits repository hygiene and categorizes project files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${PROJECT_ROOT}/out/audit"
REPORT_JSON="${OUT_DIR}/report.json"
SUMMARY_TXT="${OUT_DIR}/summary.txt"

mkdir -p "${OUT_DIR}"

FILE_LIST="$(mktemp)"
UNFINISHED_LIST="$(mktemp)"
ARTIFACT_LIST="$(mktemp)"
trap 'rm -f "${FILE_LIST}" "${UNFINISHED_LIST}" "${ARTIFACT_LIST}"' EXIT

git -C "${PROJECT_ROOT}" ls-files > "${FILE_LIST}"

STAGING_COUNT=0
DEV_COUNT=0
WIP_COUNT=0
DEMO_COUNT=0
OTHER_COUNT=0

while IFS= read -r file; do
    case "${file}" in
        staging/*)
            STAGING_COUNT=$((STAGING_COUNT + 1))
            ;;
        dev/*)
            DEV_COUNT=$((DEV_COUNT + 1))
            ;;
        wip/*|*wip*|*proto*|*experimental*|*universal_bios*|*universal-bios*)
            WIP_COUNT=$((WIP_COUNT + 1))
            ;;
        examples_and_samples/*|demo/*|*demo*|*example*|*sample*|*sandbox*|*mock*|*/bak/*)
            DEMO_COUNT=$((DEMO_COUNT + 1))
            ;;
        *)
            OTHER_COUNT=$((OTHER_COUNT + 1))
            ;;
    esac
done < "${FILE_LIST}"

# Audit unfinished markers in operational code paths.
if command -v rg >/dev/null 2>&1; then
    rg --line-number --no-heading \
        --glob 'scripts/**' \
        --glob 'utils/**' \
        --glob 'staging/**' \
        --glob '*.pf' \
        '\b(TODO|FIXME|STUB|TBD|WIP|XXX)\b' \
        "${PROJECT_ROOT}" > "${UNFINISHED_LIST}" || true
fi

# Detect common runtime artifacts that should not be tracked.
KNOWN_RUNTIME_ARTIFACTS=(
    "storage.lock"
    "userns.lock"
    "defaultNetworkBackend"
    "overlay/.has-mount-program"
    "overlay-containers/containers.lock"
    "overlay-images/images.lock"
    "overlay-layers/layers.lock"
    "issues.txt"
)

for artifact in "${KNOWN_RUNTIME_ARTIFACTS[@]}"; do
    artifact_abs="${PROJECT_ROOT}/${artifact}"
    if [ -e "${artifact_abs}" ]; then
        tracked="no"
        if git -C "${PROJECT_ROOT}" ls-files --error-unmatch "${artifact}" >/dev/null 2>&1; then
            tracked="yes"
        fi
        printf '%s|present|%s\n' "${artifact}" "${tracked}" >> "${ARTIFACT_LIST}"
    fi
done

TOTAL_FILES="$(wc -l < "${FILE_LIST}" | tr -d ' ')"
UNFINISHED_COUNT="$(wc -l < "${UNFINISHED_LIST}" | tr -d ' ')"
ARTIFACT_COUNT="$(wc -l < "${ARTIFACT_LIST}" | tr -d ' ')"

{
    echo "PhoenixGuard Repository Audit Summary"
    echo "====================================="
    echo ""
    echo "Tracked file categories:"
    echo "  STAGING: ${STAGING_COUNT}"
    echo "  DEV: ${DEV_COUNT}"
    echo "  WIP: ${WIP_COUNT}"
    echo "  DEMO: ${DEMO_COUNT}"
    echo "  OTHER: ${OTHER_COUNT}"
    echo "  TOTAL: ${TOTAL_FILES}"
    echo ""
    echo "Unfinished markers in operational code paths: ${UNFINISHED_COUNT}"
    if [ "${UNFINISHED_COUNT}" -gt 0 ]; then
        echo "  Top matches:"
        sed -n '1,20p' "${UNFINISHED_LIST}" | sed 's/^/    - /'
    fi
    echo ""
    echo "Known runtime artifact files present: ${ARTIFACT_COUNT}"
    if [ "${ARTIFACT_COUNT}" -gt 0 ]; then
        while IFS= read -r line; do
            IFS='|' read -r path state tracked <<< "${line}"
            echo "    - ${path} (${state}, tracked=${tracked})"
        done < "${ARTIFACT_LIST}"
    fi
} > "${SUMMARY_TXT}"

python3 - "${REPORT_JSON}" "${STAGING_COUNT}" "${DEV_COUNT}" "${WIP_COUNT}" "${DEMO_COUNT}" "${OTHER_COUNT}" "${TOTAL_FILES}" "${UNFINISHED_LIST}" "${ARTIFACT_LIST}" <<'PY'
import json
import sys
from pathlib import Path

report_path = Path(sys.argv[1])
staging, dev, wip, demo, other, total = map(int, sys.argv[2:8])
unfinished_file = Path(sys.argv[8])
artifact_file = Path(sys.argv[9])

unfinished_markers = []
if unfinished_file.exists():
    unfinished_markers = [line.strip() for line in unfinished_file.read_text().splitlines() if line.strip()]

runtime_artifacts = []
if artifact_file.exists():
    for line in artifact_file.read_text().splitlines():
        if not line.strip():
            continue
        path, state, tracked = line.split("|", 2)
        runtime_artifacts.append({
            "path": path,
            "state": state,
            "tracked": tracked == "yes",
        })

payload = {
    "categories": {
        "staging": staging,
        "dev": dev,
        "wip": wip,
        "demo": demo,
        "other": other,
        "total": total,
    },
    "unfinished_markers": unfinished_markers,
    "runtime_artifacts": runtime_artifacts,
}

report_path.write_text(json.dumps(payload, indent=2))
PY

echo "☠ Audit complete - see ${OUT_DIR}/"

