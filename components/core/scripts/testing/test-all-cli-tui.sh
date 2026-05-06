#!/bin/bash
# Master test runner for PhoenixBoot CLI and TUI
# Runs all CLI/TUI tests in sequence

set -euo pipefail

echo "╔════════════════════════════════════════════════════════╗"
echo "║   PhoenixBoot CLI & TUI Comprehensive Test Suite      ║"
echo "╚════════════════════════════════════════════════════════╝"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
cd "$PROJECT_ROOT"

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
SUITES_RUN=0
SUITES_PASSED=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

run_test_suite() {
    local test_script="$1"
    local test_name="$2"
    
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Running: $test_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo
    
    SUITES_RUN=$((SUITES_RUN + 1))
    
    if [ ! -f "$test_script" ]; then
        echo -e "${RED}✗ Test script not found: $test_script${NC}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        return 1
    fi
    
    if ! bash "$test_script"; then
        echo -e "${RED}✗ Test suite failed: $test_name${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Test suite passed: $test_name${NC}"
        SUITES_PASSED=$((SUITES_PASSED + 1))
        return 0
    fi
}

# Run all test suites
run_test_suite "scripts/testing/test-phoenixboot-cli.sh" "PhoenixBoot CLI Tests"
run_test_suite "scripts/testing/test-phoenixboot-tui.sh" "PhoenixBoot TUI Tests"
run_test_suite "scripts/testing/test-pf-tasks.sh" "PF Tasks Tests"

# Final Summary
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              FINAL TEST SUMMARY                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "Test Suites Run:    ${SUITES_RUN}"
echo -e "${GREEN}Suites Passed:      ${SUITES_PASSED}${NC}"
echo -e "${RED}Suites Failed:      $((SUITES_RUN - SUITES_PASSED))${NC}"
echo

if [ ${SUITES_PASSED} -eq ${SUITES_RUN} ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓✓✓ ALL TEST SUITES PASSED! ✓✓✓                     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗✗✗ SOME TEST SUITES FAILED ✗✗✗                     ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
