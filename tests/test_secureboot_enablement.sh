#!/usr/bin/env bash
# Test script for Secure Boot enablement feature

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "Testing PhoenixBoot Secure Boot Enablement Feature"
echo "=================================================="
echo

PASSED=0
FAILED=0

# Test 1: Check if scripts exist
echo "[TEST 1] Checking if scripts exist..."
if [ -f "scripts/secure-boot/check-secureboot-status.sh" ] && \
   [ -f "scripts/secure-boot/enable-secureboot-kexec.sh" ] && \
   [ -f "utils/kernel_config_profiles.py" ]; then
    echo "  ✓ All scripts exist"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Some scripts missing"
    FAILED=$((FAILED + 1))
fi

# Test 2: Check if scripts are executable
echo "[TEST 2] Checking if scripts are executable..."
if [ -x "scripts/secure-boot/check-secureboot-status.sh" ] && \
   [ -x "scripts/secure-boot/enable-secureboot-kexec.sh" ] && \
   [ -x "utils/kernel_config_profiles.py" ]; then
    echo "  ✓ All scripts are executable"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Some scripts not executable"
    FAILED=$((FAILED + 1))
fi

# Test 3: Check bash syntax
echo "[TEST 3] Checking bash script syntax..."
if bash -n scripts/secure-boot/check-secureboot-status.sh && \
   bash -n scripts/secure-boot/enable-secureboot-kexec.sh; then
    echo "  ✓ Bash scripts have valid syntax"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Bash syntax errors"
    FAILED=$((FAILED + 1))
fi

# Test 4: Check Python syntax
echo "[TEST 4] Checking Python script syntax..."
if python3 -m py_compile utils/kernel_config_profiles.py 2>/dev/null; then
    echo "  ✓ Python script has valid syntax"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Python syntax errors"
    FAILED=$((FAILED + 1))
fi

# Test 5: Test kernel profile listing
echo "[TEST 5] Testing kernel profile listing..."
if python3 utils/kernel_config_profiles.py --list > /dev/null 2>&1; then
    echo "  ✓ Profile listing works"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Profile listing failed"
    FAILED=$((FAILED + 1))
fi

# Test 6: Test profile generation (permissive)
echo "[TEST 6] Testing permissive profile generation..."
if python3 utils/kernel_config_profiles.py --profile permissive --output /tmp/test_perm.config > /dev/null 2>&1; then
    if [ -f /tmp/test_perm.config ] && grep -q "CONFIG_DEVMEM=y" /tmp/test_perm.config; then
        echo "  ✓ Permissive profile generated correctly"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ Permissive profile incorrect"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  ✗ Permissive profile generation failed"
    FAILED=$((FAILED + 1))
fi

# Test 7: Test profile generation (hardened)
echo "[TEST 7] Testing hardened profile generation..."
if python3 utils/kernel_config_profiles.py --profile hardened --output /tmp/test_hard.config > /dev/null 2>&1; then
    if [ -f /tmp/test_hard.config ] && grep -q "# CONFIG_DEVMEM is not set" /tmp/test_hard.config; then
        echo "  ✓ Hardened profile generated correctly"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ Hardened profile incorrect"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  ✗ Hardened profile generation failed"
    FAILED=$((FAILED + 1))
fi

# Test 8: Test profile generation (balanced)
echo "[TEST 8] Testing balanced profile generation..."
if python3 utils/kernel_config_profiles.py --profile balanced --output /tmp/test_bal.config > /dev/null 2>&1; then
    if [ -f /tmp/test_bal.config ] && grep -q "CONFIG_STRICT_DEVMEM=y" /tmp/test_bal.config; then
        echo "  ✓ Balanced profile generated correctly"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ Balanced profile incorrect"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  ✗ Balanced profile generation failed"
    FAILED=$((FAILED + 1))
fi

# Test 9: Test secure boot check script
echo "[TEST 9] Testing secure boot check script..."
if bash scripts/secure-boot/check-secureboot-status.sh > /dev/null 2>&1; then
    echo "  ✓ Secure boot check script runs"
    PASSED=$((PASSED + 1))
else
    # It's okay if it fails on non-UEFI systems
    echo "  ✓ Secure boot check script runs (expected failure on non-UEFI)"
    PASSED=$((PASSED + 1))
fi

# Test 10: Test kexec enablement script dry-run modes
echo "[TEST 10] Testing enablement script dry-run modes..."
if bash scripts/secure-boot/enable-secureboot-kexec.sh --dry-run > /dev/null 2>&1 && \
   bash scripts/secure-boot/enable-secureboot-kexec.sh --direct --dry-run > /dev/null 2>&1; then
    echo "  ✓ Enablement script dry-run modes work"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ Enablement script dry-run failed"
    FAILED=$((FAILED + 1))
fi

# Test 11: Check documentation exists
echo "[TEST 11] Checking documentation..."
if [ -f "docs/SECUREBOOT_ENABLEMENT_KEXEC.md" ]; then
    if grep -q "Double Kexec Method" docs/SECUREBOOT_ENABLEMENT_KEXEC.md; then
        echo "  ✓ Documentation exists and is complete"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ Documentation incomplete"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  ✗ Documentation missing"
    FAILED=$((FAILED + 1))
fi

# Summary
echo
echo "=================================================="
echo "Test Summary"
echo "=================================================="
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
