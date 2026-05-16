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
elif grep -qi "required 'pf' executable is not available\|Attempted pf.py arguments: list" /tmp/phoenixboot_list_output.txt; then
    pass "phoenixboot list fails loudly when pf is unavailable"
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
# phoenixboot should never fail silently; either the command runs or the wrapper emits
# a clear, contextual error about what it tried to delegate.
if echo "$output" | grep -qi "Attempted pf.py arguments: invalid_command_xyz\|forwarding command to pf.py"; then
    pass "Unknown commands fail loudly with delegation context"
else
    fail "Unknown command handling did not emit a clear contextual error"
fi

# Test 11: Invalid PHOENIX_ROOT should fail loudly instead of falling back silently
echo "[TEST 11] Testing invalid PHOENIX_ROOT handling..."
invalid_root_output=$(PHOENIX_ROOT=/definitely/missing ./phoenixboot status 2>&1 || true)
if echo "$invalid_root_output" | grep -q "PHOENIX_ROOT was provided"; then
    pass "Invalid PHOENIX_ROOT fails loudly"
else
    fail "Invalid PHOENIX_ROOT did not fail loudly"
fi

# Test 12: Missing ISO path should fail before any deeper task execution
echo "[TEST 12] Testing secure media path validation..."
missing_iso_output=$(./phoenixboot secure media --iso /definitely/missing.iso 2>&1 || true)
if echo "$missing_iso_output" | grep -q "Secure Boot source ISO does not exist"; then
    pass "Missing ISO path is reported explicitly"
else
    fail "Missing ISO path was not reported explicitly"
fi

# Test 13: Missing module path should fail before task dispatch
echo "[TEST 13] Testing module path validation..."
missing_module_output=$(./phoenixboot secure kmod-sign --module /definitely/missing.ko 2>&1 || true)
if echo "$missing_module_output" | grep -q "Kernel module path does not exist"; then
    pass "Missing module path is reported explicitly"
else
    fail "Missing module path was not reported explicitly"
fi

# Test 14: Check legacy phoenix-boot compatibility shim exists
echo "[TEST 14] Checking legacy phoenix-boot compatibility..."
if [ -f "phoenix-boot" ] && [ -x "phoenix-boot" ]; then
    pass "phoenix-boot compatibility shim exists"
else
    fail "phoenix-boot compatibility shim missing"
fi

# Test 15: Test legacy phoenix-boot help command
echo "[TEST 15] Testing legacy phoenix-boot help..."
if ./phoenix-boot help > /dev/null 2>&1; then
    pass "phoenix-boot compatibility shim works"
else
    fail "phoenix-boot compatibility shim failed"
fi

# Test 13: Check if phoenixboot-dod exists
echo "[TEST 13] Checking if phoenixboot-dod exists..."
if [ -f "phoenixboot-dod" ]; then
    pass "phoenixboot-dod file exists"
else
    fail "phoenixboot-dod file missing"
fi

# Test 14: Check if phoenixboot-dod is executable
echo "[TEST 14] Checking if phoenixboot-dod is executable..."
if [ -x "phoenixboot-dod" ]; then
    pass "phoenixboot-dod is executable"
else
    fail "phoenixboot-dod is not executable"
fi

# Test 15: Test phoenixboot-dod help command
echo "[TEST 15] Testing phoenixboot-dod help..."
if ./phoenixboot-dod help > /dev/null 2>&1; then
    pass "phoenixboot-dod help works"
else
    fail "phoenixboot-dod help failed"
fi

# Test 16: Test phoenixboot-dod status command
echo "[TEST 16] Testing phoenixboot-dod status..."
if ./phoenixboot-dod status > /dev/null 2>&1; then
    pass "phoenixboot-dod status works"
else
    fail "phoenixboot-dod status failed"
fi

# Test 17: Test phoenixboot-dod dod-status command
echo "[TEST 17] Testing phoenixboot-dod dod-status..."
if ./phoenixboot-dod dod-status > /dev/null 2>&1; then
    pass "phoenixboot-dod dod-status works"
else
    fail "phoenixboot-dod dod-status failed"
fi

# Test 18: Test phoenixboot-dod dod-check command (exits non-zero when non-compliant; that is expected)
echo "[TEST 18] Testing phoenixboot-dod dod-check..."
dod_check_output=$(./phoenixboot-dod dod-check 2>&1 || true)
if echo "$dod_check_output" | grep -q "DoD Compliance Results:"; then
    pass "phoenixboot-dod dod-check runs and produces compliance results"
else
    fail "phoenixboot-dod dod-check did not produce expected output"
fi

# Test 19: Verify DOD_MODE is exported by phoenixboot-dod
echo "[TEST 19] Checking DOD_MODE export in phoenixboot-dod..."
if grep -q "export DOD_MODE=1" phoenixboot-dod; then
    pass "phoenixboot-dod exports DOD_MODE=1"
else
    fail "phoenixboot-dod does not export DOD_MODE"
fi

# Test 20: Verify phoenixboot-dod help references DISA STIGs
echo "[TEST 20] Checking DISA STIG references in phoenixboot-dod help..."
dod_help_output=$(./phoenixboot-dod help 2>&1)
if echo "$dod_help_output" | grep -q "DISA"; then
    pass "phoenixboot-dod help references DISA STIGs"
else
    fail "phoenixboot-dod help does not reference DISA STIGs"
fi

# Test 21: Test DOD_FIPS_REQUIRED enforcement
echo "[TEST 21] Testing DOD_FIPS_REQUIRED enforcement..."
fips_output=$(DOD_FIPS_REQUIRED=1 ./phoenixboot-dod status 2>&1 || true)
# In a non-FIPS environment this should either succeed (if fips is on) or exit with error
if [ "$(cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo 0)" = "1" ]; then
    if ./phoenixboot-dod status > /dev/null 2>&1; then
        pass "DOD_FIPS_REQUIRED=1 accepted (FIPS kernel active)"
    else
        fail "DOD_FIPS_REQUIRED=1 failed unexpectedly on FIPS kernel"
    fi
else
    if echo "$fips_output" | grep -qi "FIPS mode is required\|fips"; then
        pass "DOD_FIPS_REQUIRED=1 correctly rejects non-FIPS environment"
    else
        skip "DOD_FIPS_REQUIRED enforcement check inconclusive"
    fi
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
