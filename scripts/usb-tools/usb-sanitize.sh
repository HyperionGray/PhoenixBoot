#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

usage() {
  cat <<'USAGE'
Usage: usb-sanitize.sh --device /dev/sdX [--force] [--force-root]

Options:
  -d, --device <path>  Target USB block device containing the FAT/EFI partition (required)
      --force          Actually delete *.pfs and vendor leftovers (default: dry-run)
      --force-root     Override the root-disk safety check
  -h, --help            Show this help text
USAGE
}

DEVICE=""
APPLY=0
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
    --force)
      APPLY=1
      ;;
    --force-root)
      FORCE_ROOT=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [ -z "$DEVICE" ]; then
  echo "☠ Target device is required" >&2
  usage
  exit 1
fi

[ -b "$DEVICE" ] || die "Device not found or not a block device: $DEVICE"
DEVICE_TYPE="$(lsblk -dn -o TYPE "$DEVICE" 2>/dev/null | head -n 1 || true)"
[ -n "$DEVICE_TYPE" ] || die "Could not determine device type for $DEVICE"
if [ "$DEVICE_TYPE" != "disk" ]; then
  die "Refusing to operate on non-disk device (type: $DEVICE_TYPE): $DEVICE"
fi
guard_not_root_disk "$DEVICE" "$FORCE_ROOT"

if [ "$APPLY" != "1" ]; then
  echo "ℹ☠  Dry-run. Use --force to perform changes."
fi

PART=$(lsblk -ln -o NAME,FSTYPE,LABEL,PATH "$DEVICE" | awk '$2~/(vfat|fat32)/ || tolower($3) ~ /efi/ {print $4; exit}')
if [ -z "$PART" ]; then
  echo "☠ Could not find FAT32/EFI partition on ${DEVICE}" >&2
  exit 1
fi

MNT=$(mktemp -d)
sudo mount "$PART" "$MNT"
trap 'sudo umount "$MNT" >/dev/null 2>&1 || true; rmdir "$MNT" >/dev/null 2>&1 || true' EXIT

echo "☠ Sanitizing ${PART} mounted at ${MNT}"
find "$MNT" -maxdepth 2 -type f -name '*.pfs' -print

if [ "$APPLY" = "1" ]; then
  find "$MNT" -maxdepth 2 -type f -name '*.pfs' -delete || true
  sudo rm -rf "$MNT/EFI/ubuntu" 2>/dev/null || true
fi

echo "☠ USB sanitize${APPLY:+ (applied)} complete"
