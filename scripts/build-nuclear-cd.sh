#!/bin/bash
# build-nuclear-cd.sh - Build PhoenixGuard Nuclear Boot recovery CD/DVD image
# This creates a bootable ISO with signed UEFI bootloader, Linux kernel, and recovery tools

set -e

echo "☠ Building PhoenixGuard Nuclear Boot recovery CD..."

# Check build requirements
echo "☠ Checking build requirements..."
for tool in xorriso grub-mkrescue; do
    if ! command -v "$tool" >/dev/null; then
        echo "ERROR: Missing $tool (install with: sudo apt install xorriso grub-efi-amd64-bin)"
        exit 1
    fi
done

# Create build workspace
echo "☠ Creating Nuclear Boot CD workspace..."
BUILD_DIR="nuclear-cd-build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"/{iso,rootfs,efi/boot}

# Prepare signed UEFI bootloader
echo "☠ Preparing signed UEFI bootloader..."
if [ -f NuclearBootEdk2.efi ]; then
    cp NuclearBootEdk2.efi "$BUILD_DIR/efi/boot/BOOTX64.EFI"
else
    echo "ERROR: NuclearBootEdk2.efi not found. Run 'make build' first."
    exit 1
fi

# Prepare Linux kernel and recovery tools
echo "☠ Preparing Linux kernel and recovery tools..."
cp "/boot/vmlinuz-$(uname -r)" "$BUILD_DIR/iso/vmlinuz" || echo "☠  Kernel copy failed"
cp "/boot/initrd.img-$(uname -r)" "$BUILD_DIR/iso/initrd.img" || echo "☠  Initramfs copy failed"

# Add recovery scripts and tools
echo "☠ Adding recovery scripts and tools..."
mkdir -p "$BUILD_DIR/iso/recovery"
cp -r scripts "$BUILD_DIR/iso/recovery/" || echo "☠  Scripts copy failed"
[ -d drivers ] && cp -r drivers "$BUILD_DIR/iso/recovery/" || echo "ℹ☠  No drivers directory"

# Create bootable ISO image
echo "☠ Creating bootable ISO image..."
if grub-mkrescue -o PhoenixGuard-Nuclear-Recovery.iso "$BUILD_DIR/" \
    --modules="part_gpt part_msdos iso9660 fat ext2 normal boot linux configfile loopback chain efifwsetup efi_gop" \
    --install-modules="linux16 linux normal iso9660 biosdisk" 2>/dev/null; then
    echo "☠ GRUB rescue succeeded"
else
    echo "GRUB rescue failed, trying xorriso directly..."
    xorriso -as mkisofs -r -V "PhoenixGuard Nuclear Recovery" \
        -o PhoenixGuard-Nuclear-Recovery.iso \
        -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -eltorito-alt-boot -e efi/boot/BOOTX64.EFI -no-emul-boot \
        "$BUILD_DIR/" || {
        echo "ERROR: Both GRUB and xorriso failed"
        exit 1
    }
fi

# Cleanup and report
rm -rf "$BUILD_DIR"

echo
echo "☠ Nuclear Boot CD created: PhoenixGuard-Nuclear-Recovery.iso"
echo "☠ Size: $(du -h PhoenixGuard-Nuclear-Recovery.iso | cut -f1)"
echo "☠ SHA256: $(sha256sum PhoenixGuard-Nuclear-Recovery.iso | cut -d' ' -f1)"
echo
echo "☠ Next steps:"
echo "  Test: make test-cd-boot"
echo "  Burn: make burn-recovery-cd"
echo "  USB:  make create-usb-recovery"
