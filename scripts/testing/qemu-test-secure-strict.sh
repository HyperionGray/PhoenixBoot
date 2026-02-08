#!/usr/bin/env bash
# Description: Runs a strict Secure Boot test in QEMU, checking for specific markers.

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
Usage: qemu-test-secure-strict.sh [--timeout SECONDS] [--no-kvm]

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

if [ ! -f out/esp/esp.img ]; then
    echo "☠ No ESP image found - run './pf.py build-package-esp' first"
    exit 1
fi
if [ ! -f out/qemu/OVMF_VARS_custom.fd ]; then
    echo "☠ Missing enrolled OVMF VARS (out/qemu/OVMF_VARS_custom.fd). Run './pf.py secure-enroll-secureboot' first."
    exit 1
fi
if [ ! -f out/setup/ovmf_code_path ]; then
    echo "☠ Missing OVMF discovery; run './pf.py build-setup'"
    exit 1
fi
OVMF_CODE_PATH=$(cat out/setup/ovmf_code_path)

echo "☠ Using OVMF (secure): $OVMF_CODE_PATH"

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
    -drive format=raw,file=out/esp/esp.img \
    -serial file:out/qemu/serial-secure-strict.log \
    -display none \
    -no-reboot || true

if grep -q "[PG-SB=OK]" out/qemu/serial-secure-strict.log && grep -q "[PG-ATTEST=OK]" out/qemu/serial-secure-strict.log; then
    TEST_RESULT="PASS"
    echo "☠ Secure boot strict test PASSED"
else
    TEST_RESULT="FAIL"
    echo "☠ Secure boot strict test FAILED"
fi

{
    echo '<?xml version="1.0" encoding="UTF-8"?>';
    echo '<testsuite name="PhoenixGuard Secure Boot Strict Test" tests="1" failures="'$([[ $TEST_RESULT == "FAIL" ]] && echo "1" || echo "0")'" time="60">';
    echo '  <testcase name="Secure Boot Strict" classname="PhoenixGuard.Secure">';
    [[ $TEST_RESULT == "FAIL" ]] && echo '    <failure message="Strict markers missing">Expected [PG-SB=OK] and [PG-ATTEST=OK]</failure>' || true;
    echo '  </testcase>';
    echo '</testsuite>';
} > out/qemu/report-secure-strict.xml

[ "$TEST_RESULT" == "PASS" ] || exit 1
