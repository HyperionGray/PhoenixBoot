#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
source includes/lib/common.sh

info "☠ Creating bootable ESP image..."
require_cmd dd
require_cmd mkfs.fat
require_cmd sbsign

ensure_dir out/esp
unmount_if_mounted out/esp/mount

detach_loops_for_image out/esp/esp.img

[ -f out/staging/BootX64.efi ] || die "No BootX64.efi found - run './pf.py build-build' first"

ESP_MB=${ESP_MB:-64}
if [ -n "${ISO_PATH:-}" ] && [ -f "${ISO_PATH}" ]; then
  ISO_BYTES=$(stat -c%s "${ISO_PATH}" 2>/dev/null || stat -f%z "${ISO_PATH}" 2>/dev/null || echo 0)
  ISO_MB=$(( (ISO_BYTES + 1048575) / 1048576 ))
  [ "$ISO_MB" -lt 64 ] && ISO_MB=64
  OVERHEAD_MB=${OVERHEAD_MB:-512}
  ESP_MB=$(( ISO_MB + OVERHEAD_MB ))
  info "Sizing ESP to ${ESP_MB} MiB for ISO inclusion (${ISO_MB} MiB ISO + ${OVERHEAD_MB} MiB overhead)"
fi

# Create image and FS
rm -f out/esp/esp.img
dd if=/dev/zero of=out/esp/esp.img bs=1M count=${ESP_MB} status=progress
mkfs.fat -F32 out/esp/esp.img

# Mount rw
ensure_dir out/esp/mount
mount_rw_loop out/esp/esp.img out/esp/mount

# Layout
sudo mkdir -p out/esp/mount/EFI/BOOT
sudo mkdir -p out/esp/mount/EFI/PhoenixGuard
sudo mkdir -p out/esp/mount/boot/grub

# Copy and sign PhoenixGuard with db key, place as default and vendor copy
if [ -f keys/db.key ] && [ -f keys/db.crt ]; then
  SIGNED_TMP=$(mktemp)
  sbsign --key keys/db.key --cert keys/db.crt \
    --output "$SIGNED_TMP" out/staging/BootX64.efi
  sudo install -D -m0644 "$SIGNED_TMP" out/esp/mount/EFI/PhoenixGuard/BootX64.efi
  rm -f "$SIGNED_TMP"
else
die "DB signing keys missing (keys/db.key, keys/db.crt). Run './pf.py secure-keygen' and './pf.py secure-make-auth' to generate and enroll keys."
fi
[ -f out/staging/KeyEnrollEdk2.efi ] && sudo cp out/staging/KeyEnrollEdk2.efi out/esp/mount/EFI/BOOT/

# Optional GRUB fragment
if [ -f staging/config/grub/user.cfg ]; then
  ok "Including user.cfg from staging/config/grub/user.cfg"
  sudo install -D -m0644 staging/config/grub/user.cfg out/esp/mount/EFI/PhoenixGuard/user.cfg
fi

# Try to include shim and grub
GRUB_SRC=""; SHIM_SRC=""
for cand in \
  "/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" \
  "/usr/lib/grub/x86_64-efi/grubx64.efi" \
  "/boot/efi/EFI/ubuntu/grubx64.efi" \
  "/boot/efi/EFI/Boot/grubx64.efi"; do
  [ -f "$cand" ] && GRUB_SRC="$cand" && break || true
done
for cand in \
  "/usr/lib/shim/shimx64.efi.signed" \
  "/usr/lib/shim/shimx64.efi" \
  "/boot/efi/EFI/ubuntu/shimx64.efi"; do
  [ -f "$cand" ] && SHIM_SRC="$cand" && break || true
done
if [ -n "$GRUB_SRC" ]; then
  ok "Found grub at $GRUB_SRC"
  sudo cp "$GRUB_SRC" out/esp/mount/EFI/PhoenixGuard/grubx64.efi
else
  warn "grubx64.efi not found on host; Clean GRUB Boot will skip grub"
fi
if [ -n "$SHIM_SRC" ]; then
  ok "Found shim at $SHIM_SRC"
  sudo cp "$SHIM_SRC" out/esp/mount/EFI/PhoenixGuard/shimx64.efi
else
  info "shimx64.efi not found on host; will attempt direct GRUB chainload"
fi

# Choose default boot path. NuclearBoot is opt-in only:
#   PG_BOOT_DEFAULT=nuclearboot ./pf.py build-package-esp
BOOT_DEFAULT_MODE="grub"
case "${PG_BOOT_DEFAULT:-grub}" in
  nuclearboot)
    BOOT_DEFAULT_MODE="nuclearboot"
    sudo install -D -m0644 out/esp/mount/EFI/PhoenixGuard/BootX64.efi out/esp/mount/EFI/BOOT/BOOTX64.EFI
    warn "Using NuclearBoot as default BOOTX64 (PG_BOOT_DEFAULT=nuclearboot)"
    ;;
  *)
    if [ -n "$SHIM_SRC" ]; then
      BOOT_DEFAULT_MODE="shim"
      sudo install -D -m0644 "$SHIM_SRC" out/esp/mount/EFI/BOOT/BOOTX64.EFI
      for mm in \
        "/usr/lib/shim/mmx64.efi.signed" \
        "/usr/lib/shim/mmx64.efi" \
        "/usr/lib/shim/MokManager.efi.signed" \
        "/usr/lib/shim/MokManager.efi"; do
        if [ -f "$mm" ]; then
          sudo install -D -m0644 "$mm" out/esp/mount/EFI/BOOT/mmx64.efi
          break
        fi
      done
    elif [ -n "$GRUB_SRC" ]; then
      BOOT_DEFAULT_MODE="grub-direct"
      sudo install -D -m0644 "$GRUB_SRC" out/esp/mount/EFI/BOOT/BOOTX64.EFI
      warn "shim not found; defaulting BOOTX64 to grubx64.efi"
    else
      BOOT_DEFAULT_MODE="nuclearboot-fallback"
      sudo install -D -m0644 out/esp/mount/EFI/PhoenixGuard/BootX64.efi out/esp/mount/EFI/BOOT/BOOTX64.EFI
      warn "Neither shim nor grub found; falling back to NuclearBoot default"
    fi
    ;;
esac

# Minimal GRUB modules (best-effort)
sudo mkdir -p out/esp/mount/boot/grub/x86_64-efi
for mod in part_gpt fat iso9660 loopback normal linux efi_gop efi_uga search regexp test ls gzio; do
  [ -f "/usr/lib/grub/x86_64-efi/${mod}.mod" ] && sudo cp "/usr/lib/grub/x86_64-efi/${mod}.mod" out/esp/mount/boot/grub/x86_64-efi/ || true
done

# Optional ISO
ISO_BASENAME=""; ISO_EXTRA_ARGS="${ISO_EXTRA_ARGS:-}"
if [ -n "${ISO_PATH:-}" ] && [ -f "${ISO_PATH}" ]; then
  ISO_BASENAME=$(basename "${ISO_PATH}")
  ok "Including ISO: ${ISO_PATH}"
  sudo mkdir -p out/esp/mount/ISO
  sudo cp "${ISO_PATH}" "out/esp/mount/ISO/${ISO_BASENAME}"
fi

# Build UUID and sidecar from signed binary on ESP
SIGNED_HASH=$(sudo sha256sum out/esp/mount/EFI/PhoenixGuard/BootX64.efi | awk '{print $1}')
BUILD_UUID=${BUILD_UUID:-${SIGNED_HASH:0:8}-${SIGNED_HASH:8:4}-${SIGNED_HASH:12:4}-${SIGNED_HASH:16:4}-${SIGNED_HASH:20:12}}
printf '%s\n' "$BUILD_UUID" > out/esp/BUILD_UUID
sudo bash -c "echo '$BUILD_UUID' > out/esp/mount/EFI/PhoenixGuard/ESP_UUID.txt"

sudo bash -c "echo $SIGNED_HASH > out/esp/mount/EFI/PhoenixGuard/NuclearBootEdk2.sha256"

# Render grub.cfg from template without expanding GRUB $ variables
TEMPLATE="scripts/templates/grub.cfg.tmpl"
[ -f "$TEMPLATE" ] || die "Template missing: $TEMPLATE"

TPL_TMP=$(mktemp)
cp "$TEMPLATE" "$TPL_TMP"

# sed-safe escape for replacements
_escape_sed() { printf '%s' "$1" | sed -e 's/[\\/&]/\\&/g'; }

BUILD_UUID_ESC=$(_escape_sed "$BUILD_UUID")
ISO_BASENAME_ESC=$(_escape_sed "$ISO_BASENAME")
ISO_EXTRA_ARGS_ESC=$(_escape_sed "$ISO_EXTRA_ARGS")

sed -i \
  -e "s|@@BUILD_UUID@@|${BUILD_UUID_ESC}|g" \
  -e "s|@@ISO_BASENAME@@|${ISO_BASENAME_ESC}|g" \
  -e "s|@@ISO_EXTRA_ARGS@@|${ISO_EXTRA_ARGS_ESC}|g" \
  "$TPL_TMP"

GRUBCFG_TMP=$(mktemp)
if [ -n "$ISO_BASENAME" ]; then
  # Keep ISO block, drop markers
  sed -e '/^# IF_HAS_ISO_START$/d' -e '/^# IF_HAS_ISO_END$/d' "$TPL_TMP" > "$GRUBCFG_TMP"
else
  # Remove ISO block entirely
  awk 'BEGIN{skip=0} /^# IF_HAS_ISO_START$/{skip=1;next} /^# IF_HAS_ISO_END$/{skip=0;next} skip==0{print}' "$TPL_TMP" > "$GRUBCFG_TMP"
fi
rm -f "$TPL_TMP"

# Append a robust auto-search ISO entry to handle unknown device paths
if [ -n "$ISO_BASENAME" ]; then
  APPEND_TMP=$(mktemp)
  cat > "$APPEND_TMP" <<'GRUBADD'
menuentry "Boot ISO (auto-search): @@ISO_BASENAME@@" {
  set isofile="/ISO/@@ISO_BASENAME@@"
  insmod search
  search --no-floppy --file $isofile --set=isodev
  if [ -z "$isodev" ]; then
    echo "ISO not found: $isofile"
    sleep 2
    return
  fi
  loopback loop ($isodev)$isofile
  if [ -f (loop)/casper/vmlinuz ]; then
    linux (loop)/casper/vmlinuz boot=casper iso-scan/filename=$isofile quiet splash ---
    if [ -f (loop)/casper/initrd ]; then
      initrd (loop)/casper/initrd
    fi
    boot
  elif [ -f (loop)/live/vmlinuz ]; then
    linux (loop)/live/vmlinuz boot=live iso-scan/filename=$isofile quiet splash ---
    if [ -f (loop)/live/initrd.img ]; then
      initrd (loop)/live/initrd.img
    fi
    boot
  elif [ -f (loop)/boot/vmlinuz ]; then
    linux (loop)/boot/vmlinuz iso-scan/filename=$isofile quiet splash ---
    if [ -f (loop)/boot/initrd ]; then
      initrd (loop)/boot/initrd
    fi
    boot
  else
    echo "No known kernel found inside ISO"
  fi
}
GRUBADD
  sed -i -e "s|@@ISO_BASENAME@@|${ISO_BASENAME_ESC}|g" "$APPEND_TMP"
  cat "$APPEND_TMP" >> "$GRUBCFG_TMP"
  rm -f "$APPEND_TMP"
fi

sudo cp "$GRUBCFG_TMP" out/esp/mount/EFI/BOOT/grub.cfg
sudo cp "$GRUBCFG_TMP" out/esp/mount/EFI/PhoenixGuard/grub.cfg
sudo cp "$GRUBCFG_TMP" out/esp/mount/boot/grub/grub.cfg
rm -f "$GRUBCFG_TMP"

# Unmount and finalize
printf '%s\n' "$BOOT_DEFAULT_MODE" > out/esp/boot-default-mode.txt
sudo umount out/esp/mount
rmdir out/esp/mount
sha256sum out/esp/esp.img > out/esp/esp.img.sha256

# Record OVMF paths if discovered
if [ -f out/setup/ovmf_code_path ] && [ -f out/setup/ovmf_vars_path ]; then
  OVMF_CODE_PATH=$(cat out/setup/ovmf_code_path)
  OVMF_VARS_PATH=$(cat out/setup/ovmf_vars_path)
  printf '%s\n%s\n' "$OVMF_CODE_PATH" "$OVMF_VARS_PATH" > out/esp/ovmf_paths.txt
  ok "Using discovered OVMF paths: $OVMF_CODE_PATH"
else
die "OVMF paths not discovered - run './pf.py build-setup' first"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ ESP (EFI System Partition) image created successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📁 Output location: out/esp/esp.img ($(du -h out/esp/esp.img | cut -f1))"
echo "   Checksum: $(cat out/esp/esp.img.sha256 | cut -d' ' -f1 | cut -c1-16)..."
echo "   Default boot mode: ${BOOT_DEFAULT_MODE}"
echo ""
echo "📦 What's inside this ESP image:"
echo ""
echo "   🔹 EFI/BOOT/BOOTX64.EFI          - Default boot entry (${BOOT_DEFAULT_MODE})"
echo "   🔹 EFI/PhoenixGuard/BootX64.efi   - PhoenixGuard vendor copy"
if [ -f out/staging/KeyEnrollEdk2.efi ]; then
echo "   🔹 EFI/BOOT/KeyEnrollEdk2.efi     - Key enrollment tool (for first-time setup)"
fi
if [ -n "$SHIM_SRC" ]; then
echo "   🔹 EFI/PhoenixGuard/shimx64.efi   - Microsoft-signed shim (from: $SHIM_SRC)"
fi
if [ -n "$GRUB_SRC" ]; then
echo "   🔹 EFI/PhoenixGuard/grubx64.efi   - GRUB bootloader"
fi
if [ -n "$ISO_BASENAME" ]; then
echo "   🔹 ISO/$ISO_BASENAME              - Your bootable ISO"
fi
echo "   🔹 EFI/BOOT/grub.cfg              - GRUB configuration"
echo "   🔹 boot/grub/x86_64-efi/*.mod     - GRUB modules"
echo ""
echo "🔐 SecureBoot keys used for signing:"
echo "   db.key + db.crt from: keys/db.*"
echo "   (Bootloader signed and ready for SecureBoot!)"
echo ""
if [ -n "$ISO_BASENAME" ]; then
echo "📚 What to do next:"
echo ""
echo "  Option 1: Create bootable USB from this ESP"
echo "    → Copy this ESP as the first partition on a USB drive"
echo "    → Or use './pf.py secureboot-create' for turnkey solution"
echo ""
echo "  Option 2: Test in QEMU"
echo "    → ./pf.py test-qemu"
echo "    → ./pf.py test-qemu-secure-positive  (with SecureBoot)"
echo ""
echo "  Option 3: Deploy to system ESP"
echo "    → Manual: sudo cp -r out/esp/mount/* /boot/efi/"
echo "    → Then update UEFI boot entries"
echo ""
else
echo "📚 What to do next:"
echo ""
echo "  1️⃣  Test this ESP in QEMU:"
echo "     ./pf.py test-qemu"
echo ""
echo "  2️⃣  Create bootable media with an ISO:"
echo "     ISO_PATH=/path/to/your.iso ./pf.py build-package-esp"
echo "     OR use the turnkey script:"
echo "     ./create-secureboot-bootable-media.sh --iso /path/to/your.iso"
echo ""
echo "  3️⃣  Deploy to your system's ESP:"
echo "     sudo cp -r EFI/PhoenixGuard /boot/efi/EFI/"
echo "     sudo efibootmgr -c -L 'PhoenixGuard' -l '\EFI\PhoenixGuard\BootX64.efi'"
echo ""
fi
echo "💡 REMINDER: The shim in this image is SIGNED"
echo "   • If you used Microsoft-signed shim: Works immediately with most systems"
echo "   • If you signed it yourself: You need to enroll your db key first"
echo ""
echo "🔗 More info:"
echo "   • Keys explained: keys/README.md"
echo "   • SecureBoot setup: SECUREBOOT_QUICKSTART.md"
echo "   • Full docs: docs/SECURE_BOOT.md"
echo ""
