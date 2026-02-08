#!/usr/bin/env bash
# Description: Creates a bootable USB drive with the production ESP.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"
# shellcheck disable=SC1091
source scripts/lib/common.sh

usage() {
  cat <<'USAGE'
Usage:
  usb-run.sh --device /dev/sdX [--esp-image path] [--iso-path file.iso] [--format TYPE]
             [--skip-sanitize] [--no-sync] [--force-root]

Options:
  --device DEVICE     Target USB block device (required)
  --esp-image PATH    ESP image to use when organizing (optional)
  --iso-path PATH     Path to ISO to copy alongside the ESP (optional)
  --format TYPE       Format the USB partition before writing (e.g. vfat, fat32, ext4)
  --skip-sanitize     Skip USB sanitization after preparation
  --no-sync           Skip the final sync step during organization
  --force-root        Override the root-disk safety check
  -h, --help          Show this help message
USAGE
}

DEVICE=""
ESP_IMAGE=""
ISO_PATH=""
FORMAT_TYPE=""
SKIP_SANITIZE=0
NO_SYNC=0
FORCE_ROOT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      [ $# -ge 2 ] || { echo "ERROR: --device requires a value" >&2; exit 2; }
      DEVICE="$2"
      shift 2
      ;;
    --esp-image)
      [ $# -ge 2 ] || { echo "ERROR: --esp-image requires a value" >&2; exit 2; }
      ESP_IMAGE="$2"
      shift 2
      ;;
    --iso-path)
      [ $# -ge 2 ] || { echo "ERROR: --iso-path requires a value" >&2; exit 2; }
      ISO_PATH="$2"
      shift 2
      ;;
    --format|--format-type)
      [ $# -ge 2 ] || { echo "ERROR: $1 requires a value" >&2; exit 2; }
      FORMAT_TYPE="$2"
      shift 2
      ;;
    --skip-sanitize)
      SKIP_SANITIZE=1
      shift
      ;;
    --no-sync)
      NO_SYNC=1
      shift
      ;;
    --force-root)
      FORCE_ROOT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

[ -n "$DEVICE" ] || { echo "ERROR: --device is required"; exit 1; }
[ -b "$DEVICE" ] || { echo "ERROR: ${DEVICE} is not a block device"; exit 1; }
DEVICE_TYPE="$(lsblk -dn -o TYPE "$DEVICE" 2>/dev/null | head -n 1 || true)"
[ -n "$DEVICE_TYPE" ] || { echo "ERROR: Could not determine device type for $DEVICE"; exit 1; }
if [ "$DEVICE_TYPE" != "disk" ]; then
  echo "ERROR: Refusing to operate on non-disk device (type: $DEVICE_TYPE): $DEVICE" >&2
  exit 1
fi
guard_not_root_disk "$DEVICE" "$FORCE_ROOT"

# Build artifacts and package ESP
./pf.py build-build build-package-esp

# Normalize ESP for Secure Boot (best-effort)
./pf.py valid-esp-secure || echo "ℹ☠ Skipping ESP secure normalization"
./pf.py verify-esp-robust

# Write to USB
PREPARE_ARGS=(--device "$DEVICE")
[ -n "$ESP_IMAGE" ] && PREPARE_ARGS+=(--esp-image "$ESP_IMAGE")
[ -n "$ISO_PATH" ] && PREPARE_ARGS+=(--iso-path "$ISO_PATH")
[ -n "$FORMAT_TYPE" ] && PREPARE_ARGS+=(--format "$FORMAT_TYPE")
[ "$NO_SYNC" -eq 1 ] && PREPARE_ARGS+=(--no-sync)
[ "$FORCE_ROOT" -eq 1 ] && PREPARE_ARGS+=(--force-root)
bash scripts/usb-tools/usb-prepare.sh "${PREPARE_ARGS[@]}"

# Sanitize USB
if [ "$SKIP_SANITIZE" -eq 0 ]; then
  SAN_ARGS=(--device "$DEVICE" --force)
  [ "$FORCE_ROOT" -eq 1 ] && SAN_ARGS+=(--force-root)
  bash scripts/usb-tools/usb-sanitize.sh "${SAN_ARGS[@]}"
else
  echo "ℹ☠ Skipping USB sanitization"
fi

echo "☠ USB prepared on ${DEVICE} — select it in firmware boot menu"
