#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib/common.sh

usage() {
  cat <<EOF
Usage: esp-add-allowed-hashes.sh [OPTIONS]

Options:
  --image PATH  ESP image to mount (default: out/esp/esp.img)
  --iso PATH    Optional ISO to include in the manifest
  -h, --help    Show this help message
EOF
  exit 0
}

IMG_ARG=""
ISO_ARG=""

while [ $# -gt 0 ]; do
  case "$1" in
    --image)
      opt="$1"; shift
      [ $# -gt 0 ] || die "Missing value for $opt"
      IMG_ARG="$1"
      shift
      ;;
    --iso)
      opt="$1"; shift
      [ $# -gt 0 ] || die "Missing value for $opt"
      ISO_ARG="$1"
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

IMG="${IMG_ARG:-out/esp/esp.img}"
ISO_PATH="${ISO_ARG:-${ISO_PATH:-}}"

[ -f "$IMG" ] || die "Missing $IMG; run 'just package-esp' first"

ensure_dir out/esp/mount
mount_rw_loop "$IMG" out/esp/mount

[ -f out/esp/mount/EFI/PhoenixGuard/BootX64.efi ] || { sudo umount out/esp/mount; rmdir out/esp/mount; die "ESP missing PhoenixGuard BootX64.efi"; }
BOOT_SHA=$(sudo sha256sum out/esp/mount/EFI/PhoenixGuard/BootX64.efi | awk '{print $1}')
: > out/esp/Allowed.manifest.sha256
printf "%s  EFI/PhoenixGuard/BootX64.efi\n" "$BOOT_SHA" >> out/esp/Allowed.manifest.sha256

if [ -n "$ISO_PATH" ]; then
  [ -f "$ISO_PATH" ] || { sudo umount out/esp/mount; rmdir out/esp/mount; die "ISO file not found: $ISO_PATH"; }
  ISO_BASENAME=$(basename "${ISO_PATH}")
  ISO_SHA=$(sha256sum "${ISO_PATH}" | awk '{print $1}')
  printf "%s  ISO/%s\n" "$ISO_SHA" "$ISO_BASENAME" >> out/esp/Allowed.manifest.sha256
fi

sudo install -D -m0644 out/esp/Allowed.manifest.sha256 out/esp/mount/EFI/PhoenixGuard/Allowed.manifest.sha256
sudo umount out/esp/mount
rmdir out/esp/mount
ok "Added Allowed.manifest.sha256 to ESP"
