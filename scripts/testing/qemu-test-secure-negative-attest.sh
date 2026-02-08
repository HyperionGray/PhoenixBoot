#!/usr/bin/env bash
# Description: Runs a negative attestation Secure Boot test in QEMU.

set -euo pipefail

die() {
    echo "$*" >&2
    exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
    cat <<'USAGE'
Usage: qemu-test-secure-negative-attest.sh [--timeout SECONDS] [--no-kvm]

Options:
  --timeout SECONDS  Timeout for the boot (default: 60)
  --no-kvm           Disable /dev/kvm acceleration even if available
  -h, --help         Show this message
USAGE
    exit 0
}

QEMU_TIMEOUT=60
DISABLE_KVM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)
      [ $# -gt 1 ] || die "--timeout requires an argument"
      QEMU_TIMEOUT="$2"
      shift 2
      ;;
    --timeout=*)
      QEMU_TIMEOUT="${1#*=}"
      shift
      ;;
    --no-kvm)
      DISABLE_KVM=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

mkdir -p out/qemu

NEG=out/esp/esp-neg-attest.img
[ -f "$NEG" ] || { echo "☠ Missing $NEG; run './pf.py build-package-esp-neg-attest'"; exit 1; }
[ -f out/qemu/OVMF_VARS_custom.fd ] || { echo "☠ Missing enrolled OVMF VARS; run './pf.py secure-enroll-secureboot'"; exit 1; }
[ -f out/setup/ovmf_code_path ] || { echo "☠ Missing OVMF discovery; run './pf.py build-setup'"; exit 1; }
OVMF_CODE_PATH=$(cat out/setup/ovmf_code_path)

QEMU_ACCEL_ARGS=()
if [ "$DISABLE_KVM" -eq 0 ] && [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    QEMU_ACCEL_ARGS=(-enable-kvm -cpu host)
else
    echo "ℹ☠  /dev/kvm not available; running without KVM acceleration"
fi

timeout ${QEMU_TIMEOUT}s qemu-system-x86_64 \
    -machine q35 \
    "${QEMU_ACCEL_ARGS[@]}" \
    -m 2G \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH" \
    -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_custom.fd \
    -drive format=raw,file="$NEG" \
    -serial file:out/qemu/serial-secure-neg-attest.log \
    -display none \
    -no-reboot || true

if grep -q "[PG-ATTEST=FAIL]" out/qemu/serial-secure-neg-attest.log && grep -q "[PG-BOOT=FAIL]" out/qemu/serial-secure-neg-attest.log; then
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
