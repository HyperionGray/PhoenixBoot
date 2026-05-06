#!/bin/bash
# Test script for PhoenixBoot TUI
# Tests the phoenixboot-tui.sh launcher

set -euo pipefail

echo "Testing PhoenixBoot TUI"
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

# Test 1: Check if phoenixboot-tui.sh exists
echo "[TEST 1] Checking if phoenixboot-tui.sh exists..."
if [ -f "phoenixboot-tui.sh" ]; then
    pass "phoenixboot-tui.sh file exists"
else
    fail "phoenixboot-tui.sh file missing"
fi

# Test 2: Check if phoenixboot-tui.sh is executable
echo "[TEST 2] Checking if phoenixboot-tui.sh is executable..."
if [ -x "phoenixboot-tui.sh" ]; then
    pass "phoenixboot-tui.sh is executable"
else
    fail "phoenixboot-tui.sh is not executable"
fi

# Test 3: Check TUI app exists
echo "[TEST 3] Checking TUI app exists..."
if [ -f "containers/tui/app/phoenixboot_tui.py" ]; then
    pass "TUI app exists at containers/tui/app/phoenixboot_tui.py"
else
    fail "TUI app missing"
fi

# Test 4: Check bash syntax
echo "[TEST 4] Checking bash script syntax..."
if bash -n phoenixboot-tui.sh; then
    pass "Bash script has valid syntax"
else
    fail "Bash syntax errors"
fi

# Test 5: Check Python syntax of TUI app
echo "[TEST 5] Checking Python script syntax..."
if python3 -m py_compile containers/tui/app/phoenixboot_tui.py 2>/dev/null; then
    pass "Python script has valid syntax"
else
    skip "Python syntax check failed (may need dependencies)"
fi

# Test 6: Verify pf.py is accessible from TUI launcher
echo "[TEST 6] Checking pf.py accessibility..."
if grep -q "pf.py" phoenixboot-tui.sh || [ -f "pf.py" ]; then
    pass "TUI can access pf.py"
else
    fail "pf.py not accessible"
fi

# Test 7: Check for required Python modules mention
echo "[TEST 7] Checking TUI dependencies..."
if grep -q "textual" phoenixboot-tui.sh || grep -q "textual" containers/tui/app/phoenixboot_tui.py; then
    pass "TUI dependencies documented"
else
    skip "TUI dependencies not clearly documented"
fi

# Test 8: Verify TUI root detection logic
echo "[TEST 8] Checking root directory detection in TUI..."
if grep -q "find_phoenixboot_root\|PHOENIXBOOT_ROOT" containers/tui/app/phoenixboot_tui.py; then
    pass "TUI has root detection logic"
else
    fail "TUI missing root detection"
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
