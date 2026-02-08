#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

usage() {
  cat <<'USAGE'
Usage: usb-write-dd.sh --device /dev/sdX [options]

Options:
  -d, --device <path>    Target block device to write (required)
  -i, --image <path>     ESP image to flash (default: out/esp/esp.img)
  -c, --confirm          Acknowledge destructive write (required)
      --force-root       Override the root-disk safety check
  -h, --help             Show this help text
USAGE
}

DEVICE=""
IMG="out/esp/esp.img"
CONFIRM=0
FORCE_ROOT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    -d|--device)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      DEVICE="$2"
      shift
      ;;
    --device=*)
      DEVICE="${1#*=}"
      ;;
    -i|--image)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      if [ -n "$2" ]; then
        IMG="$2"
      fi
      shift
      ;;
    --image=*)
      val="${1#*=}"
      if [ -n "$val" ]; then
        IMG="$val"
      fi
      ;;
    -c|--confirm)
      CONFIRM=1
      ;;
    --confirm=*)
      CONFIRM=1
      ;;
    --force-root)
      FORCE_ROOT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

[ -n "$DEVICE" ] || die "Missing --device"
[ -b "$DEVICE" ] || die "Device not found or not a block device: $DEVICE"

DEVICE_TYPE="$(lsblk -dn -o TYPE "$DEVICE" 2>/dev/null | head -n 1 || true)"
[ -n "$DEVICE_TYPE" ] || die "Could not determine device type for $DEVICE"
if [ "$DEVICE_TYPE" != "disk" ]; then
  die "Refusing to write to non-disk device (type: $DEVICE_TYPE): $DEVICE"
fi

if [ "$CONFIRM" != "1" ]; then
  die "Pass --confirm to acknowledge the destructive write"
fi

if [ ! -f "$IMG" ]; then
  die "Missing ESP image: $IMG (run './pf.py build-package-esp')"
fi

ok "Target: ${DEVICE}"
info "Listing removable devices:"
lsblk -d -o NAME,PATH,MODEL,SIZE,TRAN,RM,ROTA,TYPE | sed -n '1,200p'

guard_not_root_disk "$DEVICE" "$FORCE_ROOT"

info "Unmounting any existing mounts on ${DEVICE}…"
mapfile -t MPS < <(lsblk -ln -o MOUNTPOINT ${DEVICE} ${DEVICE}* 2>/dev/null | awk 'length') || true
for mp in "${MPS[@]:-}"; do
  warn "umount ${mp}"
  sudo umount "$mp" || sudo umount -l "$mp" || true
done
sudo partprobe "${DEVICE}" 2>/dev/null || true
sleep 1

info "Writing ${IMG} → ${DEVICE} (this will wipe the device)"
sudo dd if="$IMG" of="${DEVICE}" bs=4M status=progress oflag=direct,sync conv=fsync
sync
ok "Write complete"

MNT=/mnt/pgusb1
sudo mkdir -p "$MNT"
if sudo mount -o ro -t vfat "$DEVICE" "$MNT" 2>/dev/null; then
  ok "Mounted ${DEVICE} at ${MNT} (ro)"
  echo "Top-level:"; sudo ls -la "$MNT" | sed -n '1,200p'
  echo; echo "EFI/BOOT:"; sudo ls -lh "$MNT/EFI/BOOT" || true
  echo; echo "ISO:"; sudo ls -lh "$MNT/ISO" || true
  sudo umount "$MNT" || true
  rmdir "$MNT" 2>/dev/null || true
else
  warn "Could not mount ${DEVICE} as superfloppy; this can be normal on some hosts."
fi

ok "USB write finished — select this USB in firmware boot menu"
