#!/usr/bin/env bash
# Description: Enrolls Secure Boot keys into OVMF via QEMU without sudo.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

mkdir -p out/qemu

[ -f out/setup/ovmf_code_path ] || { echo "☠ Missing OVMF discovery; run 'just setup'"; exit 1; }
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
    --no-kvm           do not request KVM acceleration
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

echo "☠ Enrolling keys into OVMF using $OVMF_CODE_PATH (no sudo)"
QEMU_ARGS=(-machine q35 -m 512)
if [ "$DISABLE_KVM" -eq 0 ]; then
  QEMU_ARGS+=(-cpu host -enable-kvm)
else
  echo "ℹ☠  KVM acceleration disabled (--no-kvm)"
fi
QEMU_ARGS+=(
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH"
  -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_enroll.fd
  -drive format=raw,file=out/esp/enroll-esp.img
  -serial file:out/qemu/enroll.log
  -display none
  -no-reboot
)

timeout -k 5 ${TIMEOUT}s qemu-system-x86_64 "${QEMU_ARGS[@]}" || true

cp out/qemu/OVMF_VARS_enroll.fd out/qemu/OVMF_VARS_custom.fd
echo "☠ Persisted OVMF VARS at out/qemu/OVMF_VARS_custom.fd"
echo "ℹ☠  Re-run './scripts/secure-boot/enroll-secureboot-nosudo.sh --timeout <seconds> [--no-kvm]' to adjust the timeout/KVM behavior"
