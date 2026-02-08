#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

usage() {
  cat <<'USAGE'
Usage:
  organize-usb1.sh --device /dev/sdX [--esp-image path] [--iso-path file.iso] [--no-sync] [--force-root]

Options:
  --device DEVICE     Target USB block device (e.g. /dev/sdX) [required]
  --esp-image PATH    ESP image to compare against (default: out/esp/esp.img or out/esp/enroll-esp.img)
  --iso-path PATH     Populate ISO bundle metadata if ISO was copied
  --no-sync           Skip syncing the USB partition after organizing
  --force-root        Override the root-disk safety check
  -h, --help          Show this help message
USAGE
}

DEVICE=""
ESP_IMAGE=""
ISO_PATH=""
NO_SYNC=0
FORCE_ROOT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      DEVICE="${2:-}"
      shift 2
      ;;
    --esp-image)
      ESP_IMAGE="${2:-}"
      shift 2
      ;;
    --iso-path)
      ISO_PATH="${2:-}"
      shift 2
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

declare -a ESP_CANDIDATES=(out/esp/esp.img out/esp/enroll-esp.img)
IMG="$ESP_IMAGE"
if [ -z "$IMG" ]; then
  for candidate in "${ESP_CANDIDATES[@]}"; do
    if [ -f "$candidate" ]; then
      IMG="$candidate"
      break
    fi
  done
fi
[ -n "$IMG" ] || die "Missing ESP image. Set --esp-image or run './pf.py build-package-esp' (or './pf.py secure-package-esp-enroll') (checked: ${ESP_CANDIDATES[*]})."
[ -f "$IMG" ] || die "ESP image not found at $IMG"

USB_PART="$(resolve_usb_partition "$DEVICE")"
sudo mkdir -p /mnt/pgusb1 /mnt/esploop
# Mount target USB partition if not already mounted
if ! mountpoint -q /mnt/pgusb1; then
  sudo mount "$USB_PART" /mnt/pgusb1
fi
# Mount ESP image loop if not already mounted
if ! mountpoint -q /mnt/esploop; then
  sudo mount -o loop,ro "$IMG" /mnt/esploop
fi

# Sync robust grub.cfg and user.cfg
EFI_BOOT_GRUB=/mnt/esploop/EFI/BOOT/grub.cfg
if [ -f "$EFI_BOOT_GRUB" ]; then
  if ! sudo cmp -s "$EFI_BOOT_GRUB" /mnt/pgusb1/EFI/BOOT/grub.cfg 2>/dev/null; then
    info "Updating USB grub.cfg to robust version"
    sudo install -D -m0644 "$EFI_BOOT_GRUB" /mnt/pgusb1/EFI/BOOT/grub.cfg
    if [ -f /mnt/esploop/EFI/PhoenixGuard/grub.cfg ]; then
      sudo install -D -m0644 /mnt/esploop/EFI/PhoenixGuard/grub.cfg /mnt/pgusb1/EFI/PhoenixGuard/grub.cfg
    fi
    if [ -f /mnt/esploop/boot/grub/grub.cfg ]; then
      sudo install -D -m0644 /mnt/esploop/boot/grub/grub.cfg /mnt/pgusb1/boot/grub/grub.cfg || true
    fi
  fi
else
  warn "ESP image missing $EFI_BOOT_GRUB; skipping grub.cfg update"
fi
if [ -f /mnt/esploop/EFI/PhoenixGuard/user.cfg ]; then
  sudo install -D -m0644 /mnt/esploop/EFI/PhoenixGuard/user.cfg /mnt/pgusb1/EFI/PhoenixGuard/user.cfg
fi

# Normalize PhoenixGuard app location
sudo mkdir -p /mnt/pgusb1/EFI/PhoenixGuard
if [ -f /mnt/pgusb1/EFI/BOOT/BootX64.efi ]; then
  sudo mv /mnt/pgusb1/EFI/BOOT/BootX64.efi /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi
fi

# Ensure sidecar
if [ ! -f /mnt/pgusb1/EFI/PhoenixGuard/NuclearBootEdk2.sha256 ]; then
  if [ -f /mnt/esploop/EFI/PhoenixGuard/NuclearBootEdk2.sha256 ]; then
    sudo install -D -m0644 /mnt/esploop/EFI/PhoenixGuard/NuclearBootEdk2.sha256 /mnt/pgusb1/EFI/PhoenixGuard/NuclearBootEdk2.sha256
  else
    if [ -f /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi ]; then
      SHA=$(sudo sha256sum /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi | awk '{print $1}')
      echo "$SHA" | sudo tee /mnt/pgusb1/EFI/PhoenixGuard/NuclearBootEdk2.sha256 >/dev/null
    fi
  fi
fi

# Vendor shim/MokManager/grub
SHIM=""; MOKMAN=""; GRUBSIGNED=""
for cand in \
  "/usr/lib/shim/shimx64.efi.signed" \
  "/usr/lib/shim/shimx64.efi" \
  "/boot/efi/EFI/ubuntu/shimx64.efi"; do
  [ -f "$cand" ] && SHIM="$cand" && break || true
done
for cand in \
  "/usr/lib/shim/mmx64.efi.signed" \
  "/usr/lib/shim/MokManager.efi.signed" \
  "/usr/lib/shim/mmx64.efi" \
  "/usr/lib/shim/MokManager.efi"; do
  [ -f "$cand" ] && MOKMAN="$cand" && break || true
done
for cand in \
  "/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" \
  "/usr/lib/grub/x86_64-efi/monolithic/grubx64.efi"; do
  [ -f "$cand" ] && GRUBSIGNED="$cand" && break || true
done
[ -f /mnt/pgusb1/EFI/BOOT/BOOTX64.EFI ] || { [ -n "$SHIM" ] && sudo install -D -m0644 "$SHIM" /mnt/pgusb1/EFI/BOOT/BOOTX64.EFI || true; }
[ -f /mnt/pgusb1/EFI/BOOT/mmx64.efi ]   || { [ -n "$MOKMAN" ] && sudo install -D -m0644 "$MOKMAN" /mnt/pgusb1/EFI/BOOT/mmx64.efi || true; }
[ -f /mnt/pgusb1/EFI/BOOT/grubx64.efi ] || { [ -n "$GRUBSIGNED" ] && sudo install -D -m0644 "$GRUBSIGNED" /mnt/pgusb1/EFI/BOOT/grubx64.efi || true; }

# Ensure MOK key/cert and sign PhoenixGuard
ensure_dir out/keys
if [ ! -f out/keys/PGMOK.key ] || [ ! -f out/keys/PGMOK.crt ]; then
  openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -subj "/CN=PhoenixGuard MOK/" \
    -keyout "out/keys/PGMOK.key" \
    -out    "out/keys/PGMOK.crt"
  openssl x509 -in "out/keys/PGMOK.crt" -outform DER -out "out/keys/MokNew.cer"
fi
sudo install -D -m0644 "out/keys/MokNew.cer" /mnt/pgusb1/EFI/BOOT/MokNew.cer
if [ -f /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi ]; then
  sudo cp /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi.orig 2>/dev/null || true
  sbsign --key "out/keys/PGMOK.key" --cert "out/keys/PGMOK.crt" \
    --output /tmp/BootX64.signed.efi /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi || true
  sudo mv /tmp/BootX64.signed.efi /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi 2>/dev/null || true
fi

# Allowed manifest
ISO_LINE=""
if [ -n "$ISO_PATH" ] && [ -f "$ISO_PATH" ]; then
  ISO_SHA=$(sha256sum "$ISO_PATH" | awk '{print $1}')
  ISO_BASENAME=$(basename "$ISO_PATH")
  ISO_LINE="$ISO_SHA  ISO/$ISO_BASENAME"
fi
BOOT_LINE=""
if [ -f /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi ]; then
  BOOT_SHA=$(sudo sha256sum /mnt/pgusb1/EFI/PhoenixGuard/BootX64.efi | awk '{print $1}')
  BOOT_LINE="$BOOT_SHA  EFI/PhoenixGuard/BootX64.efi"
fi
{
  [ -n "$BOOT_LINE" ] && echo "$BOOT_LINE" || true
  [ -n "$ISO_LINE" ] && echo "$ISO_LINE" || true
} | tee out/esp/Allowed.manifest.sha256 >/dev/null
sudo install -D -m0644 out/esp/Allowed.manifest.sha256 /mnt/pgusb1/EFI/PhoenixGuard/Allowed.manifest.sha256

# Manifests and tree
sudo find /mnt/pgusb1 -type f -print0 | sort -z | xargs -0 sha256sum | tee "out/esp/USB1.manifest.sha256" >/dev/null
{ command -v tree >/dev/null && tree -a /mnt/pgusb1 || sudo find /mnt/pgusb1 -maxdepth 4 -type f; } \
  | tee "out/esp/USB1.tree.txt" 2>/dev/null || true

if [ "$NO_SYNC" -eq 0 ]; then
  sync
else
  info "Skipping sync because --no-sync was requested"
fi
sudo umount /mnt/esploop || true
sudo umount /mnt/pgusb1 || true
rmdir /mnt/esploop /mnt/pgusb1 2>/dev/null || true
ok "USB1 organized and verified"
