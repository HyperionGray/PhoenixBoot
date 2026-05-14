#!/bin/bash
# Focused regression test for the UUEFI source enhancements.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
cd "$PROJECT_ROOT"

UUEFI_SRC="staging/src/UUEFI.c"
UUEFI_INF="staging/src/UUEFI.inf"

PASSED=0
FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

echo "Testing UUEFI source wiring"
echo "==========================="
echo

echo "[TEST 1] Source files exist..."
if [ -f "$UUEFI_SRC" ] && [ -f "$UUEFI_INF" ]; then
    pass "UUEFI source and INF files exist"
else
    fail "UUEFI source files are missing"
fi

echo "[TEST 2] Interactive editing is fully wired..."
if grep -q "Variable index:" "$UUEFI_SRC" \
    && grep -q "ReadConsoleLine(InputBuffer" "$UUEFI_SRC" \
    && grep -q "EditVariable(SelectedIndex)" "$UUEFI_SRC" \
    && ! grep -q "Feature requires additional implementation for index input" "$UUEFI_SRC"; then
    pass "Menu-driven variable selection is implemented"
else
    fail "Interactive variable selection is not fully wired"
fi

echo "[TEST 3] Safe write path is present..."
if grep -q "UpdateVariableWithBackup" "$UUEFI_SRC" \
    && grep -q "Write was verified after applying the change" "$UUEFI_SRC" \
    && grep -q "Original value was restored when verification failed" "$UUEFI_SRC"; then
    pass "Variable writes use backup/verify messaging"
else
    fail "Safe variable write flow is missing"
fi

echo "[TEST 4] Boot media scan is wired into diagnostics..."
if grep -q "AnalyzeCurrentBootMedia" "$UUEFI_SRC" \
    && grep -q "Boot Media Scan:" "$UUEFI_SRC" \
    && grep -q "Boot media anomaly" "$UUEFI_SRC" \
    && grep -q "RefreshDiagnostics();" "$UUEFI_SRC"; then
    pass "Boot media analysis is integrated into the report/rescan flow"
else
    fail "Boot media analysis is not integrated"
fi

echo "[TEST 5] Block I/O dependency is declared..."
if grep -q "gEfiBlockIoProtocolGuid" "$UUEFI_INF"; then
    pass "UUEFI INF declares Block I/O protocol usage"
else
    fail "UUEFI INF is missing Block I/O protocol declaration"
fi

echo
echo "======================="
echo "Test Summary"
echo "======================="
echo -e "${GREEN}Passed:${NC} ${PASSED}"
echo -e "${RED}Failed:${NC} ${FAILED}"
echo

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All UUEFI source tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some UUEFI source tests failed${NC}"
    exit 1
fi
