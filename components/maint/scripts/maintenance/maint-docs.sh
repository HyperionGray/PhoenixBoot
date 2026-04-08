#!/usr/bin/env bash
# Description: Generates maintenance health documentation.

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

DOC_FILE="${OUT_DIR}/repo-health.md"
TASKS_TMP="${OUT_DIR}/_tasks.txt"
SCRIPT_LINKS_TMP="${OUT_DIR}/_script_links.txt"

# PF task inventory (best effort if pf runner is unavailable)
if ./pf.py list > "${TASKS_TMP}" 2>/dev/null; then
    TASK_COUNT="$(wc -l < "${TASKS_TMP}" | tr -d ' ')"
    TASK_STATUS="ok"
else
    TASK_COUNT="0"
    TASK_STATUS="pf-runner-unavailable"
    : > "${TASKS_TMP}"
fi

# Compatibility symlink inventory
if [ -d scripts ]; then
    ls -1 scripts > "${SCRIPT_LINKS_TMP}" 2>/dev/null || true
else
    : > "${SCRIPT_LINKS_TMP}"
fi
SCRIPT_LINK_COUNT="$(wc -l < "${SCRIPT_LINKS_TMP}" | tr -d ' ')"

# Marker scan for unfinished work in maintained paths
UNFINISHED_COUNT="$(
    rg -i "TODO|STUB|FIXME|TBD|XXX" components scripts docs TODO \
      --files-with-matches 2>/dev/null | wc -l | tr -d ' '
)"

DATE_UTC="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

{
    echo "# Repository Maintenance Health"
    echo
    echo "- Generated: ${DATE_UTC}"
    echo "- PF task list status: ${TASK_STATUS}"
    echo "- PF task count: ${TASK_COUNT}"
    echo "- scripts/ entries: ${SCRIPT_LINK_COUNT}"
    echo "- Files containing TODO/STUB/FIXME/TBD/XXX: ${UNFINISHED_COUNT}"
    echo
    echo "## Notes"
    echo
    echo "- Task count uses \`./pf.py list\` when available."
    echo "- Unfinished marker scan is informational and may include legitimate roadmap TODOs."
    echo
    echo "## scripts/ entries"
    echo
    if [ -s "${SCRIPT_LINKS_TMP}" ]; then
        sed 's/^/- /' "${SCRIPT_LINKS_TMP}"
    else
        echo "- (none)"
    fi
} > "${DOC_FILE}"

rm -f "${TASKS_TMP}" "${SCRIPT_LINKS_TMP}"

echo "Maintenance docs generated: ${DOC_FILE}"
