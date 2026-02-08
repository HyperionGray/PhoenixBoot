#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

usage() {
  cat <<'USAGE'
Usage:
  usb-enroll.sh --device /dev/sdX [--enroll-image path] [--force-root]

Options:
  --device DEVICE       Target USB block device (e.g. /dev/sdX) [required]
  --enroll-image PATH   Enrollment ESP image to copy (default: out/esp/enroll-esp.img)
  --force-root          Override the root-disk safety check
  -h, --help            Show this help message
USAGE
}

DEVICE=""
ENROLL_IMG="out/esp/enroll-esp.img"
FORCE_ROOT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      DEVICE="${2:-}"
      shift 2
      ;;
    --enroll-image)
      ENROLL_IMG="${2:-}"
      shift 2
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
      die "Unknown option: $1"
      ;;
  esac
done

[ -n "$DEVICE" ] || die "Missing --device"
[ -b "$DEVICE" ] || die "Device not found or not a block device: $DEVICE"
DEVICE_TYPE="$(lsblk -dn -o TYPE "$DEVICE" 2>/dev/null | head -n 1 || true)"
[ -n "$DEVICE_TYPE" ] || die "Could not determine device type for $DEVICE"
if [ "$DEVICE_TYPE" != "disk" ]; then
  die "Refusing to operate on non-disk device (type: $DEVICE_TYPE): $DEVICE"
fi
guard_not_root_disk "$DEVICE" "$FORCE_ROOT"
[ -f "$ENROLL_IMG" ] || die "Missing $ENROLL_IMG; run './pf.py secure-package-esp-enroll' first"

USB_PART="$(resolve_usb_partition "$DEVICE")"
info "☠ Preparing Secure Boot enrollment USB on ${DEVICE} (partition ${USB_PART})"

sudo mkdir -p /mnt/pgusb1 /mnt/enrollloop
sudo mount -o loop,ro "$ENROLL_IMG" /mnt/enrollloop
sudo mount "${USB_PART}" /mnt/pgusb1

# Copy entire enrollment ESP contents onto USB
sudo rsync -a --inplace --chmod=Du=rwx,Dg=rx,Do=rx,Fu=rw,Fg=r,Fo=r /mnt/enrollloop/ /mnt/pgusb1/

sync
sudo umount /mnt/enrollloop || true
sudo umount /mnt/pgusb1 || true
rmdir /mnt/enrollloop /mnt/pgusb1 2>/dev/null || true

ok "Enrollment USB prepared on ${DEVICE}"
