# 🔥 SecureBoot Bootable Media - Turnkey Solution

This guide explains how to create a bootable USB or CD with SecureBoot support from any ISO, in a simple and straightforward way.

## 🎯 Quick Start (TL;DR)

```bash
# One command to create bootable SecureBoot media:
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso

# Output will be in: out/esp/secureboot-bootable.img
# Write to USB with: sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress
```

That's it! The script handles everything: keys, ESP, bootloader, and enrollment.

## 📋 What This Solves

**Problem:** Creating bootable media with SecureBoot is confusing. You need to:
- Generate SecureBoot keys (PK, KEK, db)
- Sign bootloaders
- Create an ESP partition structure
- Include key enrollment tools
- Make it actually boot with SecureBoot enabled

**Solution:** One script does everything, with clear instructions for first boot.

## 🚀 Usage

### Basic Usage

```bash
./create-secureboot-bootable-media.sh --iso /path/to/your.iso
```

This creates `out/esp/secureboot-bootable.img` ready to write to USB.

### Advanced Options

```bash
# Create both USB image and ISO output
./create-secureboot-bootable-media.sh --iso ubuntu.iso --output both

# Write directly to USB (DANGEROUS - will erase USB!)
./create-secureboot-bootable-media.sh --iso ubuntu.iso --usb-device /dev/sdb

# Use existing keys instead of generating new ones
./create-secureboot-bootable-media.sh --iso ubuntu.iso --skip-keys

# Force overwrite existing files
./create-secureboot-bootable-media.sh --iso ubuntu.iso --force

# Show help
./create-secureboot-bootable-media.sh --help
```

## 📦 What Gets Created

After running the script, you'll have:

```
out/esp/
├── secureboot-bootable.img        # USB bootable image (write with dd)
└── secureboot-bootable.img.sha256 # SHA256 checksum

keys/
├── PK.key, PK.crt, PK.cer        # Platform Key
├── KEK.key, KEK.crt, KEK.cer     # Key Exchange Key
└── db.key, db.crt, db.cer        # Signature Database Key

FIRST_BOOT_INSTRUCTIONS.txt        # Detailed setup guide
```

## 🔐 What's Inside the Bootable Media

The created media includes:

1. **Your ISO** - In `/ISO/` directory, bootable via GRUB loopback
2. **SecureBoot Keys** - In `/EFI/PhoenixGuard/keys/`
   - PK, KEK, db in both .auth and .crt formats
3. **Bootloaders**
   - Microsoft-signed shim (`BOOTX64.EFI`) - for immediate SecureBoot compatibility
   - Signed GRUB (`grubx64.efi`) - for booting your ISO
   - PhoenixGuard bootloader - custom secure boot enforcement
4. **Key Enrollment Tool** - `KeyEnrollEdk2.efi` for enrolling custom keys
5. **Instructions** - `FIRST_BOOT_INSTRUCTIONS.txt` with step-by-step guide

## 🥾 First Boot - Two Ways

### Method 1: Easy Mode (Recommended for Most Users)

Use Microsoft-signed shim - works immediately on most systems:

1. **Enable SecureBoot** in BIOS/UEFI settings
2. **Boot from the media** (USB or CD)
3. **Select "Boot from ISO"** in GRUB menu
4. **Done!** Your ISO boots with SecureBoot enabled

This works because most systems already trust Microsoft's keys, and the shim is signed by Microsoft.

### Method 2: Secure Mode (Maximum Security)

Enroll your own custom PhoenixGuard keys:

1. **Boot from media** with SecureBoot **DISABLED**
2. **Select "Enroll PhoenixGuard SecureBoot Keys"** from GRUB menu
3. **Reboot** and enter BIOS/UEFI settings
4. **Enable SecureBoot**
5. **Save and reboot**
6. **Boot from media again**
7. **Select "Boot from ISO"**
8. **Done!** Your ISO now boots with YOUR custom keys

This gives you full control - only binaries signed with YOUR keys will boot.

## 🔧 Writing to USB

### Linux
```bash
# Find your USB device (usually /dev/sdb, /dev/sdc, etc.)
lsblk

# Write the image (replace /dev/sdX with your device!)
sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

### Windows
1. Download [Rufus](https://rufus.ie) or [balenaEtcher](https://www.balena.io/etcher/)
2. Select the `.img` file
3. Choose DD mode (not ISO mode!)
4. Write to USB

### macOS
```bash
# Find your USB device
diskutil list

# Write the image (replace /dev/diskX with your device!)
sudo dd if=out/esp/secureboot-bootable.img of=/dev/diskX bs=4m
```

## 💿 Burning to CD/DVD

If you used `--output iso` or `--output both`:

1. Use any CD burning software (Brasero, ImgBurn, etc.)
2. Select `out/esp/secureboot-bootable.iso`
3. Burn as a bootable disc

## 🆚 Compared to Old Workflow

### Old Way (Confusing!)
```bash
# Generate keys
./pf.py secure-keygen
./pf.py secure-make-auth

# Build artifacts
./pf.py build-setup
./pf.py build-build

# Package ESP
ISO_PATH=/path/to.iso ./pf.py build-package-esp-iso

# Create USB
USB1_DEV=/dev/sdb ./pf.py usb-prepare

# Hope it works... 🤞
```

### New Way (Simple!)
```bash
./create-secureboot-bootable-media.sh --iso /path/to.iso
# Done! 🎉
```

## 🐛 Troubleshooting

### "Security Violation" on boot
- **Cause:** SecureBoot enabled but keys not enrolled
- **Fix:** Boot with SecureBoot disabled and run key enrollment, OR use the Microsoft-signed shim

### ISO doesn't boot
- **Cause:** ISO needs specific boot parameters
- **Fix:** Check the ISO documentation for required kernel parameters. You may need to edit `grub.cfg`

### "Missing required command: sbsign"
- **Ubuntu/Debian:** `sudo apt install sbsigntool efitools openssl dosfstools`
- **Fedora/RHEL:** `sudo dnf install sbsigntools efitools openssl dosfstools`
- **Arch:** `sudo pacman -S sbsigntools efitools openssl dosfstools`

### "Verification failed" error
- **Cause:** Bootloader not signed with enrolled keys
- **Fix:** Either enroll PhoenixGuard keys, or use Microsoft-signed shim (already included!)

### "ISO not found" in GRUB
- **Cause:** ISO file path incorrect or ISO too large for ESP
- **Fix:** Check `--iso` path is correct. Script automatically sizes ESP to fit ISO + overhead.

## 📚 Key Management

Your keys are stored in `keys/` directory:

```
keys/
├── PK.key    # Platform Key (private) - KEEP SECRET!
├── PK.crt    # Platform Key (certificate)
├── KEK.key   # Key Exchange Key (private) - KEEP SECRET!
├── KEK.crt   # Key Exchange Key (certificate)
├── db.key    # Signature Database (private) - KEEP SECRET!
└── db.crt    # Signature Database (certificate)
```

**⚠️ IMPORTANT:** Back up your keys! You'll need them to:
- Sign other boot components
- Create additional bootable media
- Sign kernel modules

## 🧪 Testing in QEMU (Optional)

Before writing to real hardware, test in QEMU:

```bash
# Install QEMU if not present
sudo apt install qemu-system-x86 ovmf

# Test boot (without SecureBoot)
qemu-system-x86_64 -enable-kvm \
  -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=/tmp/OVMF_VARS.fd \
  -drive format=raw,file=out/esp/secureboot-bootable.img

# For SecureBoot testing, use OVMF with SecureBoot enabled
```

## 🎓 Understanding SecureBoot

SecureBoot prevents unauthorized code from running during boot. It uses a chain of trust:

1. **PK (Platform Key)** - Root of trust, signs KEK
2. **KEK (Key Exchange Key)** - Signs db updates
3. **db (Signature Database)** - Contains allowed signatures
4. **Bootloader** - Must be signed by key in db

This script creates all three keys and signs your bootloader with `db`, then provides tools to enroll them in your firmware.

## 📖 For More Information

- [PhoenixBoot Main README](README.md)
- [SecureBoot Deep Dive](docs/SECURE_BOOT.md)
- [Boot Sequence Documentation](docs/BOOT_SEQUENCE_AND_ATTACK_SURFACES.md)
- [GitHub Issues](https://github.com/P4X-ng/PhoenixBoot/issues)

## 🎉 Success Stories

Once you've successfully created and booted your SecureBoot media:

1. **Save your keys** somewhere safe (encrypted backup)
2. **Document your workflow** for next time
3. **Share your experience** (open an issue/discussion on GitHub)

Happy SecureBooting! 🔥
