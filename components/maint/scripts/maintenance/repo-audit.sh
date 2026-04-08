#!/usr/bin/env bash
# Audit PF task wiring and repository hygiene.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

mkdir -p out/audit

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_PATH="out/audit/maint-audit-${TIMESTAMP}.md"
LATEST_PATH="out/audit/maint-audit-latest.md"
TODO_PATH="out/audit/maint-audit-${TIMESTAMP}.todo.txt"
UNTRACKED_PATH="out/audit/maint-audit-${TIMESTAMP}.untracked.txt"
STALE_PATH="out/audit/maint-audit-${TIMESTAMP}.stale.txt"
TARGET_PATH="out/audit/maint-audit-${TIMESTAMP}.tracked-targets.txt"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
CLEANED_COUNT=0

pass() {
    local msg="$1"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "[PASS] ${msg}"
    echo "- PASS: ${msg}" >> "${REPORT_PATH}"
}

warn() {
    local msg="$1"
    WARN_COUNT=$((WARN_COUNT + 1))
    echo "[WARN] ${msg}"
    echo "- WARN: ${msg}" >> "${REPORT_PATH}"
}

fail() {
    local msg="$1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[FAIL] ${msg}"
    echo "- FAIL: ${msg}" >> "${REPORT_PATH}"
}

{
    echo "# PhoenixBoot Maintenance Audit"
    echo
    echo "- Timestamp (UTC): ${TIMESTAMP}"
    echo "- Repo: ${PROJECT_ROOT}"
    echo "- Auto clean: ${AUTO_CLEAN:-0}"
    echo
    echo "## Checks"
} > "${REPORT_PATH}"

# Check 1: os-kmod-sign wiring should use MODULE_PATH.
if rg -n 'Usage: MODULE_PATH=<file\|dir>' components/core/core.pf >/dev/null \
    && rg -n '\$\{MODULE_PATH\}' components/core/core.pf >/dev/null; then
    pass "os-kmod-sign uses MODULE_PATH in components/core/core.pf"
else
    fail "os-kmod-sign MODULE_PATH wiring is missing in components/core/core.pf"
fi

if rg -n 'Usage: PATH=<file\|dir>|\$\{PATH\}' components/core/core.pf >/dev/null; then
    fail "Legacy PATH-based os-kmod-sign wiring still exists in components/core/core.pf"
else
    pass "No PATH-based os-kmod-sign wiring remains in components/core/core.pf"
fi

# Check 2: Compatibility wrappers should include component PF files.
check_wrapper_include() {
    local wrapper="$1"
    local include_stmt="$2"
    if rg -n -F "${include_stmt}" "${wrapper}" >/dev/null; then
        pass "${wrapper} includes ${include_stmt}"
    else
        fail "${wrapper} missing include: ${include_stmt}"
    fi
}

check_wrapper_include core.pf 'include "components/core/core.pf"'
check_wrapper_include secure.pf 'include "components/secure/secure.pf"'
check_wrapper_include workflows.pf 'include "components/workflows/workflows.pf"'
check_wrapper_include maint.pf 'include "components/maint/maint.pf"'

# Check 3: Compatibility script symlinks.
check_script_symlink() {
    local link_path="$1"
    local expected_target="$2"
    if [ -L "${link_path}" ]; then
        local actual_target
        actual_target="$(readlink "${link_path}")"
        if [ "${actual_target}" = "${expected_target}" ]; then
            pass "${link_path} symlink points to ${expected_target}"
        else
            warn "${link_path} points to ${actual_target} (expected ${expected_target})"
        fi
    elif [ -e "${link_path}" ]; then
        warn "${link_path} exists but is not a symlink"
    else
        warn "${link_path} is missing"
    fi
}

check_script_symlink scripts/maintenance ../components/maint/scripts/maintenance
check_script_symlink scripts/testing ../components/core/scripts/testing
check_script_symlink scripts/secure-boot ../components/secure/scripts/secure-boot

# Check 4: Unfinished markers in active code paths (warning only).
rg -n 'TODO|STUB|FIXME|XXX|TBD|UNFINISHED' \
    components/core components/secure components/workflows components/maint \
    scripts utils tests \
    --glob '!**/*.md' > "${TODO_PATH}" || true

TODO_COUNT="$(wc -l < "${TODO_PATH}" | tr -d ' ')"
if [ "${TODO_COUNT}" -gt 0 ]; then
    warn "Found ${TODO_COUNT} unfinished marker(s) in active code paths"
    {
        echo
        echo "## Unfinished markers (first 20)"
        echo
        sed -n '1,20p' "${TODO_PATH}"
    } >> "${REPORT_PATH}"
else
    pass "No unfinished markers found in active code paths"
fi

# Check 5: Untracked files and local stale artifacts.
git ls-files --others --exclude-standard > "${UNTRACKED_PATH}" || true
UNTRACKED_COUNT="$(wc -l < "${UNTRACKED_PATH}" | tr -d ' ')"
if [ "${UNTRACKED_COUNT}" -gt 0 ]; then
    warn "Found ${UNTRACKED_COUNT} untracked file(s); review before commit"
    {
        echo
        echo "## Untracked files (first 50)"
        echo
        sed -n '1,50p' "${UNTRACKED_PATH}"
    } >> "${REPORT_PATH}"
else
    pass "No untracked files found"
fi

rg -n '(^|/)(nohup\.out.*|.*\.swp|.*\.swo|.*~|.*\.bak)$' "${UNTRACKED_PATH}" \
    | sed 's/^[0-9]\+://' > "${STALE_PATH}" || true
STALE_COUNT="$(wc -l < "${STALE_PATH}" | tr -d ' ')"

if [ "${STALE_COUNT}" -gt 0 ]; then
    warn "Found ${STALE_COUNT} stale local artifact(s)"
    if [ "${AUTO_CLEAN:-0}" = "1" ]; then
        while IFS= read -r stale_file; do
            [ -n "${stale_file}" ] || continue
            if [ -f "${stale_file}" ]; then
                rm -f -- "${stale_file}"
                CLEANED_COUNT=$((CLEANED_COUNT + 1))
            fi
        done < "${STALE_PATH}"
        pass "Removed ${CLEANED_COUNT} stale local artifact(s) (AUTO_CLEAN=1)"
    else
        warn "Set AUTO_CLEAN=1 to delete stale local artifacts"
    fi
else
    pass "No stale local artifacts detected"
fi

# Check 6: Tracked nested target directories (warning only).
git ls-files | rg '/target/' > "${TARGET_PATH}" || true
TARGET_COUNT="$(wc -l < "${TARGET_PATH}" | tr -d ' ')"
if [ "${TARGET_COUNT}" -gt 0 ]; then
    warn "Found ${TARGET_COUNT} tracked file(s) under */target/*; verify they are intentional"
    {
        echo
        echo "## Tracked */target/* paths (first 30)"
        echo
        sed -n '1,30p' "${TARGET_PATH}"
    } >> "${REPORT_PATH}"
else
    pass "No tracked */target/* paths found"
fi

{
    echo
    echo "## Summary"
    echo
    echo "- PASS: ${PASS_COUNT}"
    echo "- WARN: ${WARN_COUNT}"
    echo "- FAIL: ${FAIL_COUNT}"
    echo "- CLEANED: ${CLEANED_COUNT}"
} >> "${REPORT_PATH}"

cp "${REPORT_PATH}" "${LATEST_PATH}"

echo
echo "Audit report: ${REPORT_PATH}"
echo "Latest report: ${LATEST_PATH}"
echo "Summary: PASS=${PASS_COUNT} WARN=${WARN_COUNT} FAIL=${FAIL_COUNT} CLEANED=${CLEANED_COUNT}"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    exit 1
fi

exit 0
