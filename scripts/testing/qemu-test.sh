#!/usr/bin/env bash
# Description: Runs the main QEMU boot test.

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
Usage: qemu-test.sh [--timeout SECONDS] [--no-kvm]

Options:
  --timeout SECONDS  Timeout to wait for the boot (default: 60)
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

if [ ! -f out/esp/ovmf_paths.txt ]; then
    echo "☠ OVMF paths not found - run './pf.py build-package-esp' first"
    exit 1
fi

OVMF_CODE_PATH=$(sed -n '1p' out/esp/ovmf_paths.txt)
OVMF_VARS_PATH=$(sed -n '2p' out/esp/ovmf_paths.txt)

if [ ! -f "$OVMF_CODE_PATH" ] || [ ! -f "$OVMF_VARS_PATH" ]; then
    echo "☠ OVMF files not found at discovered paths:"
    echo "   CODE: $OVMF_CODE_PATH"
    echo "   VARS: $OVMF_VARS_PATH"
    exit 1
fi

echo "Using OVMF: $OVMF_CODE_PATH"

cp "$OVMF_VARS_PATH" out/qemu/OVMF_VARS_test.fd

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
    -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_test.fd \
    -drive format=raw,file=out/esp/esp.img \
    -serial file:out/qemu/serial.log \
    -display none \
    -no-reboot || true

if grep -q "PhoenixGuard" out/qemu/serial.log; then
    TEST_RESULT="PASS"
    echo "☠ QEMU boot test PASSED"
else
    TEST_RESULT="FAIL"
    echo "☠ QEMU boot test FAILED"
fi

{
    echo '<?xml version="1.0" encoding="UTF-8"?>';
    echo '<testsuite name="PhoenixGuard QEMU Boot Test" tests="1" failures="'$([[ $TEST_RESULT == "FAIL" ]] && echo "1" || echo "0")'" time="60">';
    echo '  <testcase name="Production Boot Test" classname="PhoenixGuard.Boot">';
    [[ $TEST_RESULT == "FAIL" ]] && echo '    <failure message="Boot test failed">No PhoenixGuard marker found in serial output</failure>' || true;
    echo '  </testcase>';
    echo '</testsuite>';
} > out/qemu/report.xml

[ "$TEST_RESULT" == "PASS" ] || exit 1
