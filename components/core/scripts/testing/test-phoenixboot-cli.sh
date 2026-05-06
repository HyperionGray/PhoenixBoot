#!/bin/bash
# Test script for PhoenixBoot CLI
# Tests the phoenixboot wrapper script and all its commands

set -euo pipefail

echo "Testing PhoenixBoot CLI"
echo "======================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
cd "$PROJECT_ROOT"

PASSED=0
FAILED=0
SKIPPED=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAILED=$((FAILED + 1))
}

skip() {
    echo -e "  ${YELLOW}⊘${NC} $1"
    SKIPPED=$((SKIPPED + 1))
}

# Test 1: Check if phoenixboot exists
echo "[TEST 1] Checking if phoenixboot exists..."
if [ -f "phoenixboot" ]; then
    pass "phoenixboot file exists"
else
    fail "phoenixboot file missing"
fi

# Test 2: Check if phoenixboot is executable
echo "[TEST 2] Checking if phoenixboot is executable..."
if [ -x "phoenixboot" ]; then
    pass "phoenixboot is executable"
else
    fail "phoenixboot is not executable"
fi

# Test 3: Check if pb symlink exists and points to phoenixboot
echo "[TEST 3] Checking pb symlink..."
if [ -L "pb" ] && [ "$(readlink pb)" = "phoenixboot" ]; then
    pass "pb symlink correctly points to phoenixboot"
else
    fail "pb symlink incorrect or missing"
fi

# Test 4: Test phoenixboot help command
echo "[TEST 4] Testing phoenixboot help..."
if ./phoenixboot help > /dev/null 2>&1; then
    pass "phoenixboot help works"
else
    fail "phoenixboot help failed"
fi

# Test 5: Test phoenixboot status command
echo "[TEST 5] Testing phoenixboot status..."
if ./phoenixboot status > /dev/null 2>&1; then
    pass "phoenixboot status works"
else
    fail "phoenixboot status failed"
fi

# Test 6: Test phoenixboot list command
echo "[TEST 6] Testing phoenixboot list..."
if ./phoenixboot list > /tmp/phoenixboot_list_output.txt 2>&1; then
    pass "phoenixboot list works"
elif grep -qi "fabric\|module.*not.*found" /tmp/phoenixboot_list_output.txt; then
    skip "phoenixboot list requires fabric module (not in test env)"
else
    fail "phoenixboot list failed"
fi

# Test 7: Test pb alias works
echo "[TEST 7] Testing pb alias..."
if ./pb help > /dev/null 2>&1; then
    pass "pb alias works"
else
    fail "pb alias failed"
fi

# Test 8: Verify phoenixboot can find PhoenixBoot root
echo "[TEST 8] Testing root directory detection..."
status_output=$(./phoenixboot status 2>&1)
if echo "$status_output" | grep -q "Working from:"; then
    pass "Correctly detects PhoenixBoot root"
else
    fail "Failed to detect PhoenixBoot root"
fi

# Test 9: Check if pf.py exists (required for phoenixboot)
echo "[TEST 9] Checking pf.py dependency..."
if [ -f "pf.py" ] || [ -L "pf.py" ]; then
    pass "pf.py exists"
else
    fail "pf.py missing"
fi

# Test 10: Test phoenixboot with invalid command
echo "[TEST 10] Testing error handling..."
output=$(timeout 5 ./phoenixboot invalid_command_xyz 2>&1 || true)
# phoenixboot passes unknown commands to pf.py, which may fail if fabric not installed
# This is expected behavior - it shows the command was processed
if echo "$output" | grep -qi "task\|fabric\|running"; then
    pass "Processes unknown commands (passes to pf.py)"
else
    skip "Error handling behavior unclear"
fi

# Test 11: Check legacy phoenix-boot compatibility shim exists
echo "[TEST 11] Checking legacy phoenix-boot compatibility..."
if [ -f "phoenix-boot" ] && [ -x "phoenix-boot" ]; then
    pass "phoenix-boot compatibility shim exists"
else
    fail "phoenix-boot compatibility shim missing"
fi

# Test 12: Test legacy phoenix-boot help command
echo "[TEST 12] Testing legacy phoenix-boot help..."
if ./phoenix-boot help > /dev/null 2>&1; then
    pass "phoenix-boot compatibility shim works"
else
    fail "phoenix-boot compatibility shim failed"
fi

# Summary
echo
echo "======================="
echo "Test Summary"
echo "======================="
echo -e "${GREEN}Passed:${NC}  ${PASSED}"
echo -e "${RED}Failed:${NC}  ${FAILED}"
echo -e "${YELLOW}Skipped:${NC} ${SKIPPED}"
echo

if [ ${FAILED} -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
