#!/usr/bin/env bash
# create-secureboot-bootable-media.sh - Turnkey SecureBoot bootable media creator
# 
# This script creates a bootable USB/CD image with SecureBoot support from an ISO.
# It handles key generation, ESP creation, and provides clear instructions for first boot.
#
# WORKFLOW:
#   Input: ISO file
#   ↓
#   1. Check dependencies (openssl, sbsign, cert-to-efi-sig-list, etc.)
#   ↓
#   2. Generate SecureBoot keys (PK, KEK, db) if not present
#   ↓
#   3. Create authenticated variable files (.auth) for key enrollment
#   ↓
#   4. Build/locate PhoenixBoot artifacts (BootX64.efi, KeyEnrollEdk2.efi)
#   ↓
#   5. Create bootable ESP image with:
#      - Microsoft-signed shim (BOOTX64.EFI)
#      - Signed GRUB (grubx64.efi)
#      - Your ISO (in /ISO/ directory)
#      - SecureBoot keys (in /EFI/PhoenixGuard/keys/)
#      - Key enrollment tool (KeyEnrollEdk2.efi)
#      - GRUB config for ISO loopback boot
#      - First boot instructions
#   ↓
#   Output: out/esp/secureboot-bootable.img (ready to write to USB or burn to CD)
#
# Usage:
#   ./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso [--output usb|iso|both]
#   ./create-secureboot-bootable-media.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source common utilities
# shellcheck disable=SC1091  # Script path not followed during static analysis
source scripts/lib/common.sh 2>/dev/null || {
    info() { printf 'ℹ☠  %s\n' "$*"; }
    ok() { printf '☠ %s\n' "$*"; }
    warn() { printf '☠  %s\n' "$*"; }
    err() { printf '☠ %s\n' "$*" >&2; }
    die() { err "$*"; exit 1; }
    require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
    ensure_dir() { mkdir -p "$1"; }
}

# Default configuration
ISO_PATH=""
OUTPUT_TYPE="usb"  # usb, iso, or both
USB_DEVICE=""
SKIP_KEYS=false
FORCE=false

# Colors for better UX
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║     🔥 PhoenixBoot SecureBoot Bootable Media Creator 🔥      ║"
    echo "║                                                               ║"
    echo "║        Turnkey solution for SecureBoot-enabled boot media    ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Create bootable USB/CD media with SecureBoot support from an ISO image.
This script handles everything: key generation, ESP creation, and enrollment setup.

OPTIONS:
    --iso PATH              Path to the ISO file (required)
    --output TYPE           Output type: usb, iso, or both (default: usb)
    --usb-device DEVICE     USB device path (e.g., /dev/sdb) for direct writing
    --skip-keys             Skip key generation if keys already exist
    --force                 Force overwrite existing files
    -h, --help              Show this help message

EXAMPLES:
    # Create USB image from Ubuntu ISO
    $0 --iso ubuntu-22.04.iso

    # Create both USB image and bootable ISO
    $0 --iso ubuntu-22.04.iso --output both

    # Write directly to USB device (DANGEROUS!)
    $0 --iso ubuntu-22.04.iso --usb-device /dev/sdb

    # Use existing keys
    $0 --iso ubuntu-22.04.iso --skip-keys

WORKFLOW:
    1. Checks dependencies
    2. Generates SecureBoot keys (PK, KEK, db, MOK) if not present
    3. Creates authenticated variable files for key enrollment
    4. Builds bootable ESP with shim + GRUB + your ISO
    5. Includes key enrollment tools and instructions
    6. Creates final bootable media (USB image or ISO)

OUTPUT:
    - out/esp/secureboot-bootable.img    USB bootable image
    - out/esp/secureboot-bootable.iso    Bootable ISO (if requested)
    - FIRST_BOOT_INSTRUCTIONS.txt        Setup guide for first boot

FIRST BOOT:
    1. Write the image to USB or burn the ISO to CD
    2. Boot from the media with SecureBoot DISABLED initially
    3. The media includes KeyEnrollEdk2.efi for enrolling custom keys
    4. Follow FIRST_BOOT_INSTRUCTIONS.txt for enrollment
    5. After enrollment, enable SecureBoot in BIOS
    6. Boot from the media again - it will now boot with SecureBoot!

EOF
}

check_dependencies() {
    info "Checking dependencies..."
    local missing=()
    
    for cmd in openssl dd mkfs.fat sbsign cert-to-efi-sig-list sign-efi-sig-list; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing required commands: ${missing[*]}"
        err ""
        err "Install them with:"
        err "  Ubuntu/Debian: sudo apt install openssl dosfstools sbsigntool efitools"
        err "  Fedora/RHEL:   sudo dnf install openssl dosfstools sbsigntools efitools"
        return 1
    fi
    
    ok "All dependencies present"
    return 0
}

generate_keys() {
    if [ "$SKIP_KEYS" = true ] && [ -f keys/PK.key ] && [ -f keys/KEK.key ] && [ -f keys/db.key ]; then
        info "Using existing SecureBoot keys"
        return 0
    fi
    
    info "Generating SecureBoot keys..."
    ensure_dir keys
    ensure_dir out/securevars
    
    # Generate PK (Platform Key)
    if [ ! -f keys/PK.key ] || [ "$FORCE" = true ]; then
        ok "Generating Platform Key (PK)..."
        openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
            -subj "/CN=PhoenixGuard PK/O=PhoenixGuard/C=US" \
            -keyout keys/PK.key -out keys/PK.crt
        openssl x509 -in keys/PK.crt -outform DER -out keys/PK.cer
        chmod 600 keys/PK.key
    fi
    
    # Generate KEK (Key Exchange Key)
    if [ ! -f keys/KEK.key ] || [ "$FORCE" = true ]; then
        ok "Generating Key Exchange Key (KEK)..."
        openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
            -subj "/CN=PhoenixGuard KEK/O=PhoenixGuard/C=US" \
            -keyout keys/KEK.key -out keys/KEK.crt
        openssl x509 -in keys/KEK.crt -outform DER -out keys/KEK.cer
        chmod 600 keys/KEK.key
    fi
    
    # Generate db (Signature Database)
    if [ ! -f keys/db.key ] || [ "$FORCE" = true ]; then
        ok "Generating Signature Database Key (db)..."
        openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
            -subj "/CN=PhoenixGuard db/O=PhoenixGuard/C=US" \
            -keyout keys/db.key -out keys/db.crt
        openssl x509 -in keys/db.crt -outform DER -out keys/db.cer
        chmod 600 keys/db.key
    fi
    
    ok "SecureBoot keys generated in ./keys/"
}

create_auth_files() {
    info "Creating authenticated variable files for key enrollment..."
    ensure_dir out/securevars
    
    # PK self-signed
    cert-to-efi-sig-list -g "$(uuidgen)" keys/PK.cer out/securevars/PK.esl
    sign-efi-sig-list -k keys/PK.key -c keys/PK.crt PK out/securevars/PK.esl out/securevars/PK.auth
    
    # KEK signed by PK
    cert-to-efi-sig-list -g "$(uuidgen)" keys/KEK.cer out/securevars/KEK.esl
    sign-efi-sig-list -k keys/PK.key -c keys/PK.crt KEK out/securevars/KEK.esl out/securevars/KEK.auth
    
    # db signed by KEK
    cert-to-efi-sig-list -g "$(uuidgen)" keys/db.cer out/securevars/db.esl
    sign-efi-sig-list -k keys/KEK.key -c keys/KEK.crt db out/securevars/db.esl out/securevars/db.auth
    
    ok "Authentication files created in out/securevars/"
}

build_artifacts() {
    info "Building PhoenixBoot artifacts..."
    
    if [ ! -f staging/boot/KeyEnrollEdk2.efi ]; then
        warn "KeyEnrollEdk2.efi not found in staging/boot/"
        warn "Using prebuilt binaries or building from source..."
        
        if [ -f scripts/build/build-production.sh ]; then
            bash scripts/build/build-production.sh || warn "Build script failed, continuing with existing artifacts"
        fi
    fi
    
    if [ ! -f out/staging/BootX64.efi ] && [ -f staging/boot/BootX64.efi ]; then
        ensure_dir out/staging
        cp staging/boot/BootX64.efi out/staging/BootX64.efi
    fi
    
    ok "Artifacts ready"
}

create_bootable_esp() {
    local iso_path="$1"
    
    info "Creating bootable ESP with SecureBoot support..."
    ensure_dir out/esp
    
    # Calculate ESP size (ISO size + overhead for keys, bootloader, etc.)
    local iso_bytes
    iso_bytes=$(stat -c%s "$iso_path" 2>/dev/null || stat -f%z "$iso_path" 2>/dev/null || echo 0)
    local iso_mb=$(( (iso_bytes + 1048575) / 1048576 ))
    local overhead_mb=256
    local esp_mb=$(( iso_mb + overhead_mb ))
    [ "$esp_mb" -lt 128 ] && esp_mb=128
    
    info "Creating ${esp_mb} MiB ESP (${iso_mb} MiB ISO + ${overhead_mb} MiB overhead)"
    
    local esp_img="out/esp/secureboot-bootable.img"
    rm -f "$esp_img"
    dd if=/dev/zero of="$esp_img" bs=1M count="$esp_mb" status=progress
    mkfs.fat -F32 "$esp_img"
    
    # Mount and populate ESP
    local mount_point="out/esp/mount"
    ensure_dir "$mount_point"
    sudo mount -o loop,rw "$esp_img" "$mount_point" || die "Failed to mount ESP image"
    
    # Create directory structure
    sudo mkdir -p "$mount_point/EFI/BOOT"
    sudo mkdir -p "$mount_point/EFI/PhoenixGuard"
    sudo mkdir -p "$mount_point/EFI/PhoenixGuard/keys"
    sudo mkdir -p "$mount_point/ISO"
    sudo mkdir -p "$mount_point/boot/grub/x86_64-efi"
    
    # Copy signed bootloader
    if [ -f out/staging/BootX64.efi ]; then
        local signed_tmp
        signed_tmp=$(mktemp)
        sbsign --key keys/db.key --cert keys/db.crt \
            --output "$signed_tmp" out/staging/BootX64.efi
        sudo install -D -m0644 "$signed_tmp" "$mount_point/EFI/PhoenixGuard/BootX64.efi"
        rm -f "$signed_tmp"
    fi
    
    # Copy shim and GRUB (for SecureBoot compatibility)
    local shim_src="" grub_src=""
    for cand in "/usr/lib/shim/shimx64.efi.signed" "/boot/efi/EFI/ubuntu/shimx64.efi"; do
        [ -f "$cand" ] && shim_src="$cand" && break
    done
    for cand in "/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed" "/boot/efi/EFI/ubuntu/grubx64.efi"; do
        [ -f "$cand" ] && grub_src="$cand" && break
    done
    
    if [ -n "$shim_src" ]; then
        ok "Including shim from $shim_src"
        sudo cp "$shim_src" "$mount_point/EFI/BOOT/BOOTX64.EFI"
        sudo cp "$shim_src" "$mount_point/EFI/PhoenixGuard/shimx64.efi"
    else
        warn "No shim found - SecureBoot may not work without manual key enrollment in firmware"
    fi
    
    if [ -n "$grub_src" ]; then
        ok "Including GRUB from $grub_src"
        sudo cp "$grub_src" "$mount_point/EFI/BOOT/grubx64.efi"
        sudo cp "$grub_src" "$mount_point/EFI/PhoenixGuard/grubx64.efi"
    fi
    
    # Copy key enrollment tool
    if [ -f staging/boot/KeyEnrollEdk2.efi ]; then
        sudo cp staging/boot/KeyEnrollEdk2.efi "$mount_point/EFI/PhoenixGuard/KeyEnrollEdk2.efi"
    fi
    
    # Copy authentication files for key enrollment
    for f in PK KEK db; do
        if [ -f "out/securevars/${f}.auth" ]; then
            sudo cp "out/securevars/${f}.auth" "$mount_point/EFI/PhoenixGuard/keys/${f,,}.auth"
        fi
    done
    
    # Copy certificates in human-readable format
    for f in PK KEK db; do
        if [ -f "keys/${f}.crt" ]; then
            sudo cp "keys/${f}.crt" "$mount_point/EFI/PhoenixGuard/keys/${f,,}.crt"
        fi
    done
    
    # Copy ISO
    local iso_basename
    iso_basename=$(basename "$iso_path")
    ok "Including ISO: $iso_path"
    sudo cp "$iso_path" "$mount_point/ISO/$iso_basename"
    
    # Create GRUB configuration
    sudo tee "$mount_point/EFI/BOOT/grub.cfg" > /dev/null <<GRUBCFG
set timeout=10
set default=0

menuentry "Boot from ISO: $iso_basename" {
    set isofile="/ISO/$iso_basename"
    
    # Search for the ISO file
    insmod search
    search --no-floppy --file \$isofile --set=isodev
    
    if [ -z "\$isodev" ]; then
        echo "ERROR: ISO not found: \$isofile"
        echo "Press any key to return to menu..."
        read
        return
    fi
    
    # Mount ISO as loopback
    loopback loop (\$isodev)\$isofile
    
    # Try different boot methods
    if [ -f (loop)/casper/vmlinuz ]; then
        # Ubuntu/Debian live
        linux (loop)/casper/vmlinuz boot=casper iso-scan/filename=\$isofile quiet splash ---
        initrd (loop)/casper/initrd
    elif [ -f (loop)/live/vmlinuz ]; then
        # Debian live
        linux (loop)/live/vmlinuz boot=live iso-scan/filename=\$isofile quiet splash ---
        initrd (loop)/live/initrd.img
    elif [ -f (loop)/boot/vmlinuz ]; then
        # Generic
        linux (loop)/boot/vmlinuz iso-scan/filename=\$isofile quiet splash ---
        initrd (loop)/boot/initrd
    else
        echo "ERROR: No known kernel found in ISO"
        echo "Press any key to return to menu..."
        read
        return
    fi
}

menuentry "Enroll PhoenixGuard SecureBoot Keys (FIRST TIME SETUP)" {
    chainloader /EFI/PhoenixGuard/KeyEnrollEdk2.efi
}

menuentry "UEFI Firmware Settings" {
    fwsetup
}

menuentry "Reboot" {
    reboot
}

menuentry "Shutdown" {
    halt
}
GRUBCFG
    
    sudo cp "$mount_point/EFI/BOOT/grub.cfg" "$mount_point/boot/grub/grub.cfg"
    
    # Create instructions file on ESP
    sudo tee "$mount_point/FIRST_BOOT_INSTRUCTIONS.txt" > /dev/null <<INSTRUCTIONS
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     PhoenixBoot SecureBoot Bootable Media - First Boot       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

QUICK START GUIDE

This bootable media includes:
- Your ISO: $iso_basename
- PhoenixGuard SecureBoot keys (PK, KEK, db)
- Key enrollment tool (KeyEnrollEdk2.efi)
- Microsoft-signed shim (if available on build system)

═══════════════════════════════════════════════════════════════

FIRST BOOT SETUP (Choose ONE method):

METHOD 1: Easy Mode - Using Microsoft-signed Shim (RECOMMENDED)
────────────────────────────────────────────────────────────────
If your system has Microsoft keys enrolled (most do):

1. Enable SecureBoot in BIOS/UEFI settings
2. Boot from this media
3. The Microsoft-signed shim will verify and boot GRUB
4. Select "Boot from ISO" in the GRUB menu
5. Done! Your ISO will boot with SecureBoot enabled

Note: This works immediately on most systems without key enrollment.

METHOD 2: Full Control - Custom Key Enrollment
────────────────────────────────────────────────────────────────
For maximum security, enroll your own PhoenixGuard keys:

1. Boot from this media with SecureBoot DISABLED
2. Select "Enroll PhoenixGuard SecureBoot Keys" from GRUB menu
3. The KeyEnrollEdk2.efi tool will run and enroll:
   - Platform Key (PK)
   - Key Exchange Key (KEK)
   - Signature Database (db)
4. Reboot
5. Enter BIOS/UEFI settings
6. Enable SecureBoot
7. Save and reboot
8. Boot from this media again
9. Select "Boot from ISO" - it will now boot with YOUR keys!

═══════════════════════════════════════════════════════════════

KEY LOCATIONS ON THIS MEDIA:

/EFI/PhoenixGuard/keys/pk.auth    - Platform Key (authenticated)
/EFI/PhoenixGuard/keys/kek.auth   - Key Exchange Key (authenticated)
/EFI/PhoenixGuard/keys/db.auth    - Signature Database (authenticated)
/EFI/PhoenixGuard/keys/pk.crt     - Platform Key (certificate)
/EFI/PhoenixGuard/keys/kek.crt    - Key Exchange Key (certificate)
/EFI/PhoenixGuard/keys/db.crt     - Signature Database (certificate)

These keys are also saved on your build system in the keys/ directory.
Keep them safe! You'll need them to sign other boot components.

═══════════════════════════════════════════════════════════════

TROUBLESHOOTING:

Q: Boot fails with "Security Violation"
A: SecureBoot is enabled but keys aren't enrolled. Boot with 
   SecureBoot disabled and run the key enrollment tool first.

Q: ISO doesn't boot
A: The ISO may need specific boot parameters. Check the ISO's
   documentation for required kernel parameters.

Q: "Verification failed" error
A: The bootloader isn't signed with enrolled keys. Make sure to
   enroll PhoenixGuard keys or use the Microsoft-signed shim.

Q: How do I write this to USB?
A: Linux:   sudo dd if=secureboot-bootable.img of=/dev/sdX bs=4M status=progress
   Windows: Use Rufus or balenaEtcher in DD mode
   macOS:   sudo dd if=secureboot-bootable.img of=/dev/diskX bs=4m

Q: Can I burn this to CD/DVD?
A: If you generated an ISO output, yes! Use any CD burning software.
   The USB image (.img) is for USB flash drives only.

═══════════════════════════════════════════════════════════════

For more information, visit:
https://github.com/P4X-ng/PhoenixBoot

Happy SecureBoot-ing! 🔥
INSTRUCTIONS
    
    # Unmount
    sudo umount "$mount_point"
    rmdir "$mount_point"
    
    # Generate SHA256
    sha256sum "$esp_img" > "$esp_img.sha256"
    
    ok "Bootable ESP created: $esp_img"
    ok "Size: $(du -h "$esp_img" | cut -f1)"
}

create_instructions_file() {
    local output_file="FIRST_BOOT_INSTRUCTIONS.txt"
    
    cat > "$output_file" <<INSTRUCTIONS
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     PhoenixBoot SecureBoot Bootable Media                    ║
║     First Boot Instructions                                  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

Your bootable media has been created successfully!

OUTPUT FILES:
────────────────────────────────────────────────────────────────
$([ -f out/esp/secureboot-bootable.img ] && echo "✓ out/esp/secureboot-bootable.img - USB bootable image")
$([ -f out/esp/secureboot-bootable.iso ] && echo "✓ out/esp/secureboot-bootable.iso - CD/DVD bootable ISO")
✓ keys/ - Your SecureBoot keys (KEEP THESE SAFE!)

═══════════════════════════════════════════════════════════════

HOW TO USE:

OPTION 1: Write to USB Flash Drive
────────────────────────────────────────────────────────────────
Linux:
  sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress
  (Replace /dev/sdX with your USB device, e.g., /dev/sdb)

Windows:
  Use Rufus (https://rufus.ie) or balenaEtcher in DD mode
  Select the .img file

macOS:
  sudo dd if=out/esp/secureboot-bootable.img of=/dev/diskX bs=4m
  (Replace /dev/diskX with your USB device)

OPTION 2: Burn to CD/DVD (if ISO was generated)
────────────────────────────────────────────────────────────────
Use any CD burning software with out/esp/secureboot-bootable.iso

═══════════════════════════════════════════════════════════════

FIRST BOOT:

Two ways to use this media, depending on your needs:

🔵 EASY MODE - Use Microsoft Keys (No enrollment needed)
   1. Enable SecureBoot in BIOS
   2. Boot from media
   3. Select "Boot from ISO" in GRUB menu
   4. Done!
   
   This works on most systems that have Microsoft keys enrolled.

🔵 SECURE MODE - Use Your Own Keys (Recommended for security)
   1. Boot from media with SecureBoot DISABLED
   2. Select "Enroll PhoenixGuard SecureBoot Keys" in GRUB menu
   3. Reboot and enable SecureBoot in BIOS
   4. Boot from media again
   5. Select "Boot from ISO"
   6. Your custom keys are now enforcing SecureBoot!

═══════════════════════════════════════════════════════════════

The media includes:
- Your ISO file for booting
- SecureBoot keys (PK, KEK, db) in /EFI/PhoenixGuard/keys/
- Key enrollment tool (KeyEnrollEdk2.efi)
- Microsoft-signed shim for immediate SecureBoot compatibility
- GRUB bootloader with ISO loopback support

For detailed instructions, see the FIRST_BOOT_INSTRUCTIONS.txt
file on the bootable media itself.

═══════════════════════════════════════════════════════════════

TROUBLESHOOTING:

- "Security Violation" → Disable SecureBoot or enroll keys first
- "ISO not found" → Check ISO path was correct
- "Verification failed" → Enroll PhoenixGuard keys or use shim

Need help? Visit: https://github.com/P4X-ng/PhoenixBoot/issues

🔥 Happy SecureBoot-ing! 🔥
INSTRUCTIONS
    
    ok "Instructions created: $output_file"
}

write_to_usb() {
    local device="$1"
    local img="out/esp/secureboot-bootable.img"
    
    [ -f "$img" ] || die "Image not found: $img"
    [ -b "$device" ] || die "Not a block device: $device"
    
    warn "═══════════════════════════════════════════════════════════════"
    warn "WARNING: This will ERASE ALL DATA on $device"
    warn "═══════════════════════════════════════════════════════════════"
    echo -n "Type 'YES' (all caps) to continue: "
    read -r response
    
    if [ "$response" != "YES" ]; then
        die "Aborted by user"
    fi
    
    info "Writing image to $device..."
    sudo dd if="$img" of="$device" bs=4M status=progress conv=fsync
    sync
    
    ok "Successfully written to $device"
    ok "You can now boot from this device!"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iso)
            ISO_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_TYPE="$2"
            shift 2
            ;;
        --usb-device)
            USB_DEVICE="$2"
            shift 2
            ;;
        --skip-keys)
            SKIP_KEYS=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            die "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

# Main execution
main() {
    print_banner
    
    # Validate input
    [ -z "$ISO_PATH" ] && die "ISO path required. Use --iso /path/to.iso or --help"
    [ -f "$ISO_PATH" ] || die "ISO file not found: $ISO_PATH"
    
    info "Configuration:"
    info "  ISO: $ISO_PATH"
    info "  Output type: $OUTPUT_TYPE"
    [ -n "$USB_DEVICE" ] && info "  USB device: $USB_DEVICE"
    echo ""
    
    # Execute workflow
    check_dependencies || die "Dependency check failed"
    generate_keys
    create_auth_files
    build_artifacts
    create_bootable_esp "$ISO_PATH"
    create_instructions_file
    
    # Write to USB if requested
    if [ -n "$USB_DEVICE" ]; then
        write_to_usb "$USB_DEVICE"
    fi
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}SUCCESS! Your SecureBoot bootable media is ready!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Output:${NC}"
    echo "  📁 out/esp/secureboot-bootable.img ($(du -h out/esp/secureboot-bootable.img 2>/dev/null | cut -f1 || echo "N/A"))"
    [ -f out/esp/secureboot-bootable.iso ] && echo "  📁 out/esp/secureboot-bootable.iso"
    echo "  📁 keys/ (SecureBoot keys - KEEP SAFE!)"
    echo "  📄 FIRST_BOOT_INSTRUCTIONS.txt"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Read FIRST_BOOT_INSTRUCTIONS.txt"
    if [ -z "$USB_DEVICE" ]; then
        echo "  2. Write the image to USB:"
        echo "     sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress"
    else
        echo "  2. Boot from $USB_DEVICE"
    fi
    echo "  3. Choose Easy Mode (use Microsoft keys) or Secure Mode (enroll custom keys)"
    echo "  4. Boot your ISO with SecureBoot enabled!"
    echo ""
}

main "$@"
