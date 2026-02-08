#!/usr/bin/env bash
# Description: Prepare a USB drive with PhoenixGuard's ESP image and optional ISO.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

usage() {
  cat <<'USAGE'
Usage:
  usb-prepare.sh --device /dev/sdX [--esp-image path] [--format TYPE] [--iso-path file.iso]
               [--skip-organize] [--no-sync] [--force-root]

Options:
  --device DEVICE     Target USB block device (e.g. /dev/sdX) [required]
  --esp-image PATH    ESP image to write (default: first of out/esp/esp.img or out/esp/enroll-esp.img)
  --format TYPE       Format the USB partition with TYPE (e.g. vfat, fat32, ext4)
  --iso-path PATH     Copy an ISO file into ISO/ on the USB (optional)
  --skip-organize     Skip the optional usb organization step
  --no-sync           Skip the final sync step during organization
  --force-root        Override the root-disk safety check
  -h, --help          Show this help message
USAGE
}

format_usb_partition() {
  local fs="$1" tgt="$2"
  case "${fs,,}" in
    vfat|fat32)
      require_cmd mkfs.vfat
      sudo mkfs.vfat -F32 "$tgt"
      ;;
    fat)
      require_cmd mkfs.fat
      sudo mkfs.fat -F32 "$tgt"
      ;;
    *)
      require_cmd "mkfs.${fs}"
      sudo "mkfs.${fs}" "$tgt"
      ;;
  esac
}

copy_with_progress() {
  local src="$1" dst="$2"
  if command -v rsync >/dev/null 2>&1; then
    rsync --info=progress2 "$src" "$dst"
  elif command -v pv >/dev/null 2>&1; then
    pv "$src" | sudo tee "$dst" >/dev/null
  else
    sudo install -D -m0644 "$src" "$dst"
  fi
}

cleanup_mounts() {
  for m in /mnt/esploop /mnt/pgusb1; do
    if mountpoint -q "$m" 2>/dev/null; then
      sudo umount "$m" || sudo umount -l "$m" || true
    fi
    rmdir "$m" 2>/dev/null || true
  done
}

DEVICE=""
ESP_IMAGE=""
FORMAT_TYPE=""
ISO_PATH=""
SKIP_ORGANIZE=0
NO_SYNC=0
FORCE_ROOT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      [ $# -ge 2 ] || die "--device requires a value"
      DEVICE="${2}"
      shift 2
      ;;
    --esp-image)
      [ $# -ge 2 ] || die "--esp-image requires a value"
      ESP_IMAGE="${2}"
      shift 2
      ;;
    --format|--format-type)
      [ $# -ge 2 ] || die "Missing argument for $1"
      FORMAT_TYPE="${2}"
      shift 2
      ;;
    --iso-path)
      [ $# -ge 2 ] || die "--iso-path requires a value"
      ISO_PATH="${2}"
      shift 2
      ;;
    --skip-organize)
      SKIP_ORGANIZE=1
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

IMG="$ESP_IMAGE"
if [ -z "$IMG" ]; then
  for cand in out/esp/esp.img out/esp/enroll-esp.img; do
    if [ -f "$cand" ]; then
      IMG="$cand"
      break
    fi
  done
fi
[ -n "$IMG" ] || die "No ESP image found (looked in out/esp/esp.img and out/esp/enroll-esp.img)"
[ -f "$IMG" ] || die "ESP image not found: $IMG"

USB_PART="$(resolve_usb_partition "$DEVICE")"

if [ -n "$FORMAT_TYPE" ]; then
  info "Formatting ${USB_PART} as ${FORMAT_TYPE}"
  sudo umount "$USB_PART" >/dev/null 2>&1 || true
  format_usb_partition "$FORMAT_TYPE" "$USB_PART"
  sudo partprobe "$DEVICE" >/dev/null 2>&1 || true
fi

info "Preparing secure USB on ${DEVICE} (partition ${USB_PART})"
trap cleanup_mounts EXIT

sudo mkdir -p /mnt/pgusb1 /mnt/esploop
if mountpoint -q /mnt/esploop; then sudo umount /mnt/esploop || sudo umount -l /mnt/esploop || true; fi
if mountpoint -q /mnt/pgusb1; then sudo umount /mnt/pgusb1 || sudo umount -l /mnt/pgusb1 || true; fi

sudo mount -o loop,ro "$IMG" /mnt/esploop
sudo mount "$USB_PART" /mnt/pgusb1

if [ -n "$ISO_PATH" ]; then
  [ -f "$ISO_PATH" ] || die "ISO file not found: $ISO_PATH"
  ISO_BASENAME="$(basename "$ISO_PATH")"
  sudo mkdir -p /mnt/pgusb1/ISO
  copy_with_progress "$ISO_PATH" "/mnt/pgusb1/ISO/${ISO_BASENAME}"
fi

cleanup_mounts

if [ "$SKIP_ORGANIZE" -eq 0 ]; then
  ORGANIZE_ARGS=(--device "$DEVICE" --esp-image "$IMG")
  [ -n "$ISO_PATH" ] && ORGANIZE_ARGS+=(--iso-path "$ISO_PATH")
  [ "$NO_SYNC" -eq 1 ] && ORGANIZE_ARGS+=(--no-sync)
  bash scripts/usb-tools/organize-usb1.sh "${ORGANIZE_ARGS[@]}"
else
  info "Skipping USB organization"
fi

info "Secure USB prepared on ${DEVICE}"
