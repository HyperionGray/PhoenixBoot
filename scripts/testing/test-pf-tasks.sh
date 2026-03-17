#!/bin/bash
# Comprehensive test script for all pf.py tasks
# Tests that all tasks are defined and can at least be invoked

set -euo pipefail

echo "Testing PhoenixBoot pf.py Tasks"
echo "==============================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"
TASK_LIST_OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$TASK_LIST_OUTPUT_FILE"' EXIT

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

# Test 1: Check if pf.py exists
echo "[TEST 1] Checking if pf.py exists..."
if [ -f "pf.py" ] || [ -L "pf.py" ]; then
    pass "pf.py exists"
else
    fail "pf.py missing"
fi

# Test 2: Check if pf.py is executable
echo "[TEST 2] Checking if pf.py is executable..."
if [ -x "pf.py" ]; then
    pass "pf.py is executable"
else
    fail "pf.py is not executable"
fi

# Test 3: Check if Pfyfile.pf exists
echo "[TEST 3] Checking if Pfyfile.pf exists..."
if [ -f "Pfyfile.pf" ]; then
    pass "Pfyfile.pf exists"
else
    fail "Pfyfile.pf missing"
fi

# Test 4: Check core.pf exists
echo "[TEST 4] Checking if core.pf exists..."
if [ -f "core.pf" ]; then
    pass "core.pf exists"
else
    fail "core.pf missing"
fi

# Test 5: Check secure.pf exists
echo "[TEST 5] Checking if secure.pf exists..."
if [ -f "secure.pf" ]; then
    pass "secure.pf exists"
else
    fail "secure.pf missing"
fi

# Test 6: Check workflows.pf exists
echo "[TEST 6] Checking if workflows.pf exists..."
if [ -f "workflows.pf" ]; then
    pass "workflows.pf exists"
else
    fail "workflows.pf missing"
fi

# Test 7: Check maint.pf exists
echo "[TEST 7] Checking if maint.pf exists..."
if [ -f "maint.pf" ]; then
    pass "maint.pf exists"
else
    fail "maint.pf missing"
fi

# Test 8: Verify pf.py can list tasks (dry run)
echo "[TEST 8] Testing pf.py list command..."
# Note: This will fail if fabric module is not installed, which is expected
if ./pf.py list > "$TASK_LIST_OUTPUT_FILE" 2>&1; then
    if grep -q "task\|build\|test" "$TASK_LIST_OUTPUT_FILE"; then
        pass "pf.py list command works"
    else
        skip "pf.py list succeeded but output format unclear"
    fi
else
    # Check if it's due to missing dependencies
    if grep -qi "fabric\|module.*not.*found" "$TASK_LIST_OUTPUT_FILE"; then
        skip "pf.py requires fabric module (not installed in test env)"
    else
        fail "pf.py list failed"
    fi
fi

# Test 9: Check syntax of all .pf files
echo "[TEST 9] Checking .pf files for basic syntax..."
pf_syntax_ok=true
for pf_file in *.pf; do
    if [ -f "$pf_file" ]; then
        # Check for basic task structure
        if grep -q "^task " "$pf_file"; then
            pass "$pf_file has task definitions"
        else
            skip "$pf_file has no tasks (may be include-only)"
        fi
    fi
done

# Test 10: Verify key tasks are defined in core.pf
echo "[TEST 10] Checking for essential tasks in core.pf..."
essential_tasks=(
    "build-setup"
    "build-build"
    "test-qemu"
    "secure-keygen"
    "setup"
    "verify"
)

for task in "${essential_tasks[@]}"; do
    if grep -q "^task $task" core.pf; then
        pass "Task '$task' is defined"
    else
        fail "Task '$task' is missing"
    fi
done

# Test 11: Verify task descriptions exist
echo "[TEST 11] Checking task descriptions..."
if grep -q "describe " core.pf; then
    pass "Tasks have descriptions"
else
    fail "No task descriptions found"
fi

# Test 12: Check for shell command usage in tasks
echo "[TEST 12] Verifying tasks use shell commands..."
if grep -q "shell " core.pf; then
    pass "Tasks use shell commands"
else
    fail "No shell commands in tasks"
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
