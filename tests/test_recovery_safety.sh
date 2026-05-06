#!/bin/bash
set -euo pipefail

echo "Testing PhoenixBoot recovery safety messaging and guards"
echo "======================================================="
echo

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

echo "[TEST 1] Bash syntax for recovery shell scripts..."
if bash -n scripts/recovery/reboot-to-vm.sh \
          scripts/recovery/reboot-to-metal.sh \
          scripts/recovery/nuclear-wipe.sh \
          scripts/recovery/hardware-recovery.sh; then
    pass "Recovery shell scripts have valid syntax"
else
    fail "Recovery shell scripts contain syntax errors"
fi

echo "[TEST 2] Python syntax for recovery orchestrators..."
if python3 -m py_compile scripts/recovery/phoenix_progressive.py scripts/recovery/autonuke.py 2>/dev/null; then
    pass "Recovery orchestrators have valid syntax"
else
    fail "Recovery orchestrators contain syntax errors"
fi

echo "[TEST 3] reboot-to-vm stages the correct installer path..."
if grep -q "./scripts/recovery/install_kvm_snapshot_jump.sh" scripts/recovery/reboot-to-vm.sh && \
   [ -x "scripts/recovery/install_kvm_snapshot_jump.sh" ]; then
    pass "reboot-to-vm uses the recovery installer path"
else
    fail "reboot-to-vm is not using the expected installer path"
fi

echo "[TEST 4] Destructive recovery entry points expose explicit risk levels..."
if grep -q "Risk Level: HIGH" scripts/recovery/reboot-to-vm.sh && \
   grep -q "Risk Level: CRITICAL" scripts/recovery/nuclear-wipe.sh && \
   grep -q "Risk Level: CRITICAL" scripts/recovery/hardware-recovery.sh; then
    pass "Shell entry points include explicit risk level messaging"
else
    fail "Missing risk level messaging in destructive shell entry points"
fi

echo "[TEST 5] nuclear-wipe requires stronger target confirmation..."
if grep -q "ERASE RUNNING SYSTEM" scripts/recovery/nuclear-wipe.sh && \
   grep -q "Type the exact device path" scripts/recovery/nuclear-wipe.sh; then
    pass "nuclear-wipe has extra confirmations for dangerous targets"
else
    fail "nuclear-wipe is missing the stronger confirmation flow"
fi

echo "[TEST 6] Progressive recovery surfaces concrete risk assessments..."
if grep -q "def print_risk_assessment" scripts/recovery/phoenix_progressive.py && \
   grep -q "def normalize_risk_level" scripts/recovery/phoenix_progressive.py && \
   grep -q "risk_level in {\"HIGH\", \"CRITICAL\"}" scripts/recovery/phoenix_progressive.py && \
   grep -q "def print_risk_assessment" scripts/recovery/autonuke.py; then
    pass "Python recovery flows include risk assessment guidance"
else
    fail "Python recovery flows are missing risk assessment guidance"
fi

echo
echo "======================================================="
echo "Test Summary"
echo "======================================================="
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
echo

if [ ${FAILED} -eq 0 ]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
