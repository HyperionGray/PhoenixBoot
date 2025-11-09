# 🔥 PhoenixBoot SecureBoot Quick Reference Card

## One-Command Bootable Media Creation

```bash
./create-secureboot-bootable-media.sh --iso /path/to/your.iso
```

Output: `out/esp/secureboot-bootable.img` (ready to write to USB)

## Write to USB

```bash
# Linux
sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress

# Windows: Use Rufus in DD mode
# macOS:   sudo dd if=out/esp/secureboot-bootable.img of=/dev/diskX bs=4m
```

## First Boot - Two Options

### 🟢 Easy Mode (Most Users)
1. Enable SecureBoot in BIOS
2. Boot from media
3. Select "Boot from ISO" in GRUB
4. Done! ✅

Uses Microsoft-signed shim - works immediately!

### 🔵 Secure Mode (Maximum Security)
1. Boot with SecureBoot **OFF**
2. Select "Enroll PhoenixGuard SecureBoot Keys"
3. Reboot, enable SecureBoot in BIOS
4. Boot from media again
5. Select "Boot from ISO"
6. Done with YOUR keys! 🔐

## Common Options

```bash
# Show help
./create-secureboot-bootable-media.sh --help

# Use existing keys
./create-secureboot-bootable-media.sh --iso your.iso --skip-keys

# Write directly to USB (DANGEROUS!)
./create-secureboot-bootable-media.sh --iso your.iso --usb-device /dev/sdb
```

## Install Dependencies

```bash
# Ubuntu/Debian
sudo apt install openssl dosfstools sbsigntool efitools

# Fedora/RHEL
sudo dnf install openssl dosfstools sbsigntools efitools

# Arch
sudo pacman -S openssl dosfstools sbsigntools efitools
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Security Violation" | Disable SecureBoot OR enroll keys first |
| "ISO not found" | Check ISO path, or ESP may be too small |
| Missing sbsign | Install dependencies (see above) |
| "Verification failed" | Enroll PhoenixGuard keys or use shim |

## What You Get

- ✅ Bootable USB/CD image with your ISO
- ✅ SecureBoot keys (PK, KEK, db) in `keys/`
- ✅ Key enrollment tool on the media
- ✅ Microsoft-signed shim (works immediately)
- ✅ Instructions on the media itself

## Key Files

```
out/esp/secureboot-bootable.img    # USB image
keys/PK.key, PK.crt                # Platform Key
keys/KEK.key, KEK.crt              # Key Exchange Key
keys/db.key, db.crt                # Signature Database
FIRST_BOOT_INSTRUCTIONS.txt        # Detailed guide
```

## Full Documentation

See: `docs/SECUREBOOT_BOOTABLE_MEDIA.md`

---

**Made with 🔥 by PhoenixBoot**
