#!/usr/bin/env bash
# Description: Enrolls Secure Boot keys into OVMF via QEMU.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

mkdir -p out/qemu

[ -f out/setup/ovmf_code_path ] || { echo "☠ Missing OVMF discovery; run './pf.py build-setup'"; exit 1; }
OVMF_CODE_PATH=$(cat out/setup/ovmf_code_path)
OVMF_VARS_PATH=$(cat out/setup/ovmf_vars_path)

cp "$OVMF_VARS_PATH" out/qemu/OVMF_VARS_enroll.fd

TIMEOUT=120
DISABLE_KVM=0

usage() {
  cat <<EOF
Usage: $0 [--timeout SECONDS] [--no-kvm]

Options:
    --timeout SECONDS  relax qemu timeout (default: ${TIMEOUT})
    --no-kvm           run without /dev/kvm even if available
    -h, --help         show this help message
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)
      if [ $# -lt 2 ]; then
        echo "☠ --timeout requires an argument"
        usage
      fi
      TIMEOUT="$2"
      shift 2
      ;;
    --timeout=*)
      TIMEOUT="${1#*=}"
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
      echo "☠ Unknown option: $1"
      usage
      ;;
  esac
done

echo "☠ Enrolling keys into OVMF using $OVMF_CODE_PATH"
QEMU_ACCEL_ARGS=()
if [ "$DISABLE_KVM" -eq 0 ]; then
  if [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    QEMU_ACCEL_ARGS=(-enable-kvm -cpu host)
  else
    echo "ℹ☠  /dev/kvm not available; running without KVM acceleration"
  fi
else
  echo "ℹ☠  Running without KVM acceleration (--no-kvm)"
fi

timeout -k 5 ${TIMEOUT}s qemu-system-x86_64 \
    -machine q35 \
    "${QEMU_ACCEL_ARGS[@]}" \
    -m 512 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH" \
    -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_enroll.fd \
    -drive format=raw,file=out/esp/enroll-esp.img \
    -serial file:out/qemu/enroll.log -display none -no-reboot || true

cp out/qemu/OVMF_VARS_enroll.fd out/qemu/OVMF_VARS_custom.fd
echo "☠ Persisted OVMF VARS at out/qemu/OVMF_VARS_custom.fd"
echo "ℹ☠  If secure tests fail, re-run './scripts/secure-boot/enroll-secureboot.sh --timeout <seconds> [--no-kvm]'"
