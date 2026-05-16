#!/bin/bash
# Focused regression test for alpha-gated UUEFI host-side helpers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
cd "$PROJECT_ROOT"

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

echo "Testing UUEFI host-side helper safety"
echo "====================================="
echo

echo "[TEST 1] uuefi-install is alpha-gated by default..."
install_output=$(bash scripts/uefi-tools/uuefi-install.sh 2>&1 || true)
if echo "$install_output" | grep -q "gated off for the alpha release"; then
    pass "uuefi-install refuses to run without explicit opt-in"
else
    fail "uuefi-install did not enforce the alpha gate"
fi

echo "[TEST 2] uuefi-apply is alpha-gated by default..."
apply_output=$(bash scripts/uefi-tools/uuefi-apply.sh 2>&1 || true)
if echo "$apply_output" | grep -q "gated off for the alpha release"; then
    pass "uuefi-apply refuses to run without explicit opt-in"
else
    fail "uuefi-apply did not enforce the alpha gate"
fi

echo "[TEST 3] uuefi-install refuses BootX64 placeholder fallback..."
missing_binary_output=$(PHOENIXBOOT_ALPHA_ALLOW_UNTESTED_UUEFI_HOST=1 UUEFI_SRC=/definitely/missing/UUEFI.efi bash scripts/uefi-tools/uuefi-install.sh 2>&1 || true)
if echo "$missing_binary_output" | grep -q "Refusing to fall back to BootX64.efi"; then
    pass "uuefi-install requires a real UUEFI binary"
else
    fail "uuefi-install still allows a BootX64 placeholder fallback"
fi

echo
echo "======================="
echo "Test Summary"
echo "======================="
echo -e "${GREEN}Passed:${NC} ${PASSED}"
echo -e "${RED}Failed:${NC} ${FAILED}"
echo

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All UUEFI host-helper tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some UUEFI host-helper tests failed${NC}"
    exit 1
fi
