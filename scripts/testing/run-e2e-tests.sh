#!/usr/bin/env bash
# Run all end-to-end tests locally
# This mimics what GitHub Actions does

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "🔥 PhoenixBoot End-to-End Test Suite"
echo "====================================="
echo ""

# Check for required commands
MISSING_DEPS=()
for cmd in qemu-system-x86_64 genisoimage mcopy mkfs.fat sbsign cert-to-efi-sig-list sign-efi-sig-list; do
    if ! command -v $cmd &> /dev/null; then
        MISSING_DEPS+=($cmd)
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "❌ Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install qemu-system-x86 ovmf mtools genisoimage dosfstools sbsigntool util-linux"
    exit 1
fi

# Ensure toolchain is present and OVMF paths are discovered
echo "🔎 Checking toolchain..."
./pf.py build-setup

# Track results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

run_test() {
    local name="$1"
    local command="$2"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 Running: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if eval "$command"; then
        echo "✅ PASSED: $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAILED: $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("$name")
    fi
}

# Ensure SecureBoot key material exists (needed for ESP packaging + secure tests)
echo ""
echo "🔐 Ensuring SecureBoot key material..."
if [ ! -f keys/PK.key ] || [ ! -f keys/KEK.key ] || [ ! -f keys/db.key ]; then
    ./pf.py secure-keygen
fi
if [ ! -f out/securevars/PK.auth ] || [ ! -f out/securevars/KEK.auth ] || [ ! -f out/securevars/db.auth ]; then
    ./pf.py secure-make-auth
fi

# Ensure artifacts are built
echo "📦 Building artifacts..."
if [ ! -f out/esp/esp.img ]; then
    ./pf.py build-build
    ./pf.py build-package-esp
fi

# Test 1: Basic Boot
run_test "Basic QEMU Boot" "./pf.py test-qemu"

# Test 2: UUEFI
run_test "UUEFI Diagnostic Tool" "./pf.py test-qemu-uuefi"

# Test 3: Cloud-Init
run_test "Cloud-Init Integration" "./pf.py test-qemu-cloudinit"

# Test 4: SecureBoot
echo ""
echo "🔐 Setting up SecureBoot enrollment media..."
if [ ! -f out/esp/enroll-esp.img ]; then
    ./pf.py secure-package-esp-enroll
fi

# Enroll keys
if [ ! -f out/qemu/OVMF_VARS_custom.fd ]; then
    ./pf.py secure-enroll-secureboot
fi

run_test "SecureBoot Positive" "./pf.py test-qemu-secure-positive"
run_test "SecureBoot Strict" "./pf.py test-qemu-secure-strict"

# Test 5: Corruption Detection
echo ""
echo "🛡️ Setting up corruption detection test..."
if [ ! -f out/esp/esp-neg-attest.img ]; then
    ./pf.py build-package-esp-neg-attest
fi

# This test should fail (detecting corruption is the success condition)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Running: Corruption Detection (Negative Attestation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TESTS_RUN=$((TESTS_RUN + 1))

if ./pf.py test-qemu-secure-negative-attest 2>&1 | tee /tmp/neg-test.log; then
    # Test succeeded, but it shouldn't have
    echo "❌ FAILED: Corruption Detection (boot should have failed)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("Corruption Detection")
else
    # Test failed as expected, check if it was for the right reason
    if grep -q "PG-ATTEST=FAIL" out/qemu/serial-secure-neg-attest.log; then
        echo "✅ PASSED: Corruption Detection (correctly detected hash mismatch)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "❌ FAILED: Corruption Detection (failed for wrong reason)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS+=("Corruption Detection")
    fi
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total:  $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    echo "❌ Failed tests:"
    for test in "${FAILED_TESTS[@]}"; do
        echo "  - $test"
    done
    echo ""
    echo "View logs in out/qemu/"
    exit 1
else
    echo "✅ All tests passed!"
    echo ""
    echo "Test artifacts:"
    echo "  - Logs: out/qemu/serial*.log"
    echo "  - Reports: out/qemu/report*.xml"
    exit 0
fi
