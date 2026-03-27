#!/bin/bash
# Comprehensive test script for all pf.py tasks
# Tests that all tasks are defined and can at least be invoked

set -euo pipefail

echo "Testing PhoenixBoot pf.py Tasks"
echo "==============================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
cd "$PROJECT_ROOT"

CORE_TASK_FILE="components/core/core.pf"
SECURE_TASK_FILE="components/secure/secure.pf"
WORKFLOW_TASK_FILE="components/workflows/workflows.pf"
MAINT_TASK_FILE="components/maint/maint.pf"

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

# Test 4: Check core task files exist
echo "[TEST 4] Checking if core task files exist..."
if [ -f "core.pf" ] && [ -f "$CORE_TASK_FILE" ]; then
    pass "core.pf compatibility wrapper and component file exist"
else
    fail "core task files missing"
fi

# Test 5: Check secure task files exist
echo "[TEST 5] Checking if secure task files exist..."
if [ -f "secure.pf" ] && [ -f "$SECURE_TASK_FILE" ]; then
    pass "secure.pf compatibility wrapper and component file exist"
else
    fail "secure task files missing"
fi

# Test 6: Check workflow task files exist
echo "[TEST 6] Checking if workflow task files exist..."
if [ -f "workflows.pf" ] && [ -f "$WORKFLOW_TASK_FILE" ]; then
    pass "workflows.pf compatibility wrapper and component file exist"
else
    fail "workflow task files missing"
fi

# Test 7: Check maintenance task files exist
echo "[TEST 7] Checking if maint task files exist..."
if [ -f "maint.pf" ] && [ -f "$MAINT_TASK_FILE" ]; then
    pass "maint.pf compatibility wrapper and component file exist"
else
    fail "maintenance task files missing"
fi

# Test 8: Verify pf.py can list tasks (dry run)
echo "[TEST 8] Testing pf.py list command..."
# Note: This will fail if fabric module is not installed, which is expected
if ./pf.py list > /tmp/pf_tasks.txt 2>&1; then
    if grep -q "task\|build\|test" /tmp/pf_tasks.txt; then
        pass "pf.py list command works"
    else
        skip "pf.py list succeeded but output format unclear"
    fi
else
    # Check if it's due to missing dependencies
    if grep -qi "fabric\|module.*not.*found\|pf runner not found" /tmp/pf_tasks.txt; then
        skip "pf.py runtime dependency is not installed in test env"
    else
        fail "pf.py list failed"
    fi
fi

# Test 9: Check syntax of all .pf files
echo "[TEST 9] Checking .pf files for basic syntax..."
pf_syntax_ok=true
for pf_file in Pfyfile.pf core.pf secure.pf workflows.pf maint.pf "$CORE_TASK_FILE" "$SECURE_TASK_FILE" "$WORKFLOW_TASK_FILE" "$MAINT_TASK_FILE" components/*/Pfyfile.pf; do
    if [ -f "$pf_file" ]; then
        # Check for basic task structure
        if grep -q "^task " "$pf_file"; then
            pass "$pf_file has task definitions"
        else
            skip "$pf_file has no tasks (may be include-only)"
        fi
    fi
done

# Test 10: Verify key tasks are defined in the core component
echo "[TEST 10] Checking for essential tasks in the core component..."
essential_tasks=(
    "build-setup"
    "build-build"
    "test-qemu"
    "secure-keygen"
    "setup"
    "verify"
)

for task in "${essential_tasks[@]}"; do
    if grep -q "^task $task" "$CORE_TASK_FILE"; then
        pass "Task '$task' is defined"
    else
        fail "Task '$task' is missing"
    fi
done

# Test 11: Verify task descriptions exist
echo "[TEST 11] Checking task descriptions..."
if grep -q "describe " "$CORE_TASK_FILE"; then
    pass "Tasks have descriptions"
else
    fail "No task descriptions found"
fi

# Test 12: Check for shell command usage in tasks
echo "[TEST 12] Verifying tasks use shell commands..."
if grep -q "shell " "$CORE_TASK_FILE"; then
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
