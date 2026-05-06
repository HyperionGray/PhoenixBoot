#!/bin/bash
# Test script for PhoenixBoot DoD helper commands

set -euo pipefail

echo "Testing PhoenixBoot DoD helpers"
echo "==============================="
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

pass() {
    echo "  ✓ $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo "  ✗ $1"
    FAILED=$((FAILED + 1))
}

echo "[TEST 1] Checking DoD helper files..."
if [ -d "DoD" ] && [ -f "DoD/disa_stig_helper.py" ] && [ -f "DoD/README.md" ]; then
    pass "DoD helper directory and files exist"
else
    fail "DoD helper files missing"
fi

echo "[TEST 2] Checking DoD tasks..."
if grep -q "^task dod-info" components/core/core.pf \
   && grep -q "^task dod-stig-check" components/core/core.pf \
   && grep -q "^task dod-secure-config" components/core/core.pf; then
    pass "DoD tasks are defined"
else
    fail "DoD tasks missing from core task file"
fi

echo "[TEST 3] Checking distro-aware info output..."
if python3 DoD/disa_stig_helper.py info --distro ubuntu > /tmp/dod_info.txt 2>&1 \
   && grep -q "Distribution: ubuntu" /tmp/dod_info.txt \
   && grep -q "Compliance focus:" /tmp/dod_info.txt; then
    pass "Info command reports distro-aware guidance"
else
    fail "Info command output missing expected guidance"
fi

echo "[TEST 4] Checking secure config generation..."
TMP_CONFIG="/tmp/phoenixboot_dod_secure_kernel.config"
if python3 DoD/disa_stig_helper.py generate-secure-config --distro rhel --output "$TMP_CONFIG" > /tmp/dod_config.txt 2>&1 \
   && [ -f "$TMP_CONFIG" ] \
   && grep -q "Distro family: RHEL-like" "$TMP_CONFIG" \
   && grep -q "CONFIG_MODULE_SIG_FORCE=y" "$TMP_CONFIG"; then
    pass "Secure config generation is distro-aware"
else
    fail "Secure config generation failed"
fi

echo
echo "======================="
echo "Test Summary"
echo "======================="
echo "Passed:  $PASSED"
echo "Failed:  $FAILED"
echo

if [ "$FAILED" -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
fi

echo "✗ Some tests failed"
exit 1
