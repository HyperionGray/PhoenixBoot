#!/usr/bin/env bash
# Description: Runs a negative attestation Secure Boot test in QEMU.

set -euo pipefail
mkdir -p out/qemu

NEG=out/esp/esp-neg-attest.img
[ -f "$NEG" ] || { echo "☠ Missing $NEG; run './pf.py build-package-esp-neg-attest'"; exit 1; }
[ -f out/qemu/OVMF_VARS_custom.fd ] || { echo "☠ Missing enrolled OVMF VARS; run './pf.py secure-enroll-secureboot'"; exit 1; }
[ -f out/setup/ovmf_code_path ] || { echo "☠ Missing OVMF discovery; run './pf.py build-setup'"; exit 1; }
OVMF_CODE_PATH=$(cat out/setup/ovmf_code_path)

QT=${PG_QEMU_TIMEOUT:-60}
QEMU_CPU="-cpu max"
QEMU_ACCEL=()
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    QEMU_CPU="-cpu host"
    QEMU_ACCEL=(-enable-kvm)
fi

timeout ${QT}s qemu-system-x86_64 \
    -machine q35 \
    ${QEMU_CPU} \
    "${QEMU_ACCEL[@]}" \
    -m 2G \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH" \
    -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_custom.fd \
    -drive format=raw,file="$NEG" \
    -serial file:out/qemu/serial-secure-neg-attest.log \
    -display none \
    -no-reboot || true

# Expect attestation failure markers
if grep -q "\[PG-ATTEST=FAIL\]" out/qemu/serial-secure-neg-attest.log && grep -q "\[PG-BOOT=FAIL\]" out/qemu/serial-secure-neg-attest.log; then
    TEST_RESULT="PASS"
    echo "☠ Negative attestation test PASSED (fail-closed)"
else
    TEST_RESULT="FAIL"
    echo "☠ Negative attestation test FAILED (expected fail-closed markers)"
fi

{
    echo '<?xml version="1.0" encoding="UTF-8"?>';
    echo '<testsuite name="PhoenixGuard Secure Boot Negative Attest Test" tests="1" failures="'$([[ $TEST_RESULT == "FAIL" ]] && echo "1" || echo "0")'" time="60">';
    echo '  <testcase name="Secure Boot Negative Attest" classname="PhoenixGuard.Secure">';
    [[ $TEST_RESULT == "FAIL" ]] && echo '    <failure message="Expected [PG-ATTEST=FAIL] and [PG-BOOT=FAIL]">Markers not found</failure>' || true;
    echo '  </testcase>';
    echo '</testsuite>';
} > out/qemu/report-secure-neg-attest.xml

[ "$TEST_RESULT" == "PASS" ] || exit 1

