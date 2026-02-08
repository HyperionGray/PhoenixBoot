#!/usr/bin/env bash
# Description: Launches QEMU with a GUI to enable Secure Boot in the OVMF menu.

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
Usage: qemu-run-secure-ui.sh [--no-kvm]

Options:
  --no-kvm        Disable /dev/kvm acceleration even if available
  -h, --help      Show this message
USAGE
    exit 0
}

DISABLE_KVM=0
while [ $# -gt 0 ]; do
  case "$1" in
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

[ -f out/esp/esp.img ] || { echo "☠ No ESP image found - run './pf.py build-package-esp' first"; exit 1; }
[ -f out/setup/ovmf_code_path ] || { echo "☠ Missing OVMF discovery; run './pf.py build-setup'"; exit 1; }
[ -f out/qemu/OVMF_VARS_custom.fd ] || { echo "☠ Missing enrolled OVMF VARS (out/qemu/OVMF_VARS_custom.fd). Run './pf.py secure-enroll-secureboot' first"; exit 1; }

OVMF_CODE_PATH=$(cat out/setup/ovmf_code_path)

# Use a copy so interactive changes persist separately
cp out/qemu/OVMF_VARS_custom.fd out/qemu/OVMF_VARS_secure_ui.fd

echo "Launching QEMU GUI to enable Secure Boot in OVMF UI"
echo "   In the UI: Device Manager → Secure Boot Configuration → Enable Secure Boot, ensure Setup Mode is disabled, then Save & Exit."

QEMU_ACCEL_ARGS=()
if [ "$DISABLE_KVM" -eq 0 ] && [ -c /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    QEMU_ACCEL_ARGS=(-enable-kvm -cpu host)
else
    echo "ℹ☠  /dev/kvm not available; running without KVM acceleration"
fi

exec qemu-system-x86_64 \
    -machine q35 \
    "${QEMU_ACCEL_ARGS[@]}" \
    -m 2048 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH" \
    -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_secure_ui.fd \
    -drive format=raw,file=out/esp/esp.img \
    -display gtk,gl=on \
    -serial stdio
