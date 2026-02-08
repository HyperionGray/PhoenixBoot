#!/usr/bin/env bash
set -euo pipefail

# QEMU GUI run using the packaged ESP
# Exits with error if ESP or OVMF paths are missing

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

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

# Prepare a writable VARS store for this run
cp "$OVMF_VARS_PATH" out/qemu/OVMF_VARS_run.fd

# Choose acceleration if KVM is available
ACCEL_ARGS=""
CPU_ARGS="-cpu qemu64"
if [ -r /dev/kvm ]; then
  ACCEL_ARGS="-enable-kvm"
  CPU_ARGS="-cpu host"
fi

echo "Launching QEMU (GUI) using: $OVMF_CODE_PATH"
exec qemu-system-x86_64 \
  -machine q35 \
  $CPU_ARGS \
  $ACCEL_ARGS \
  -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH" \
  -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_run.fd \
  -drive format=raw,file=out/esp/esp.img \
  -display gtk,gl=on \
  -serial stdio
