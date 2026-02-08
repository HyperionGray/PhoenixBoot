# 🔥 PhoenixBoot SecureBoot Quick Reference

## One-Command USB Creation (Recommended)

```bash
./create-secureboot-bootable-media.sh --iso /path/to/your.iso --usb-device /dev/sdX
# (or: ./pf.py secureboot-create iso_path=/path/to/your.iso usb_device=/dev/sdX  # alias secureboot-create-usb)
```

- The script will ask whether you want to generate new SecureBoot keys (PK/KEK/db).
- It will erase the selected USB device.

## Common Options

```bash
# Help
./create-secureboot-bootable-media.sh --help

# Skip touching keys (just write the ISO)
./create-secureboot-bootable-media.sh --iso your.iso --usb-device /dev/sdX --skip-keys

# Force brand-new keys (backs up existing keys first)
./create-secureboot-bootable-media.sh --iso your.iso --usb-device /dev/sdX --new-keys

# Non-interactive (DANGEROUS)
./create-secureboot-bootable-media.sh --iso your.iso --usb-device /dev/sdX --skip-keys --yes

# Verify the write (slow)
./create-secureboot-bootable-media.sh --iso your.iso --usb-device /dev/sdX --skip-keys --verify

# Preview what would happen
./create-secureboot-bootable-media.sh --iso your.iso --usb-device /dev/sdX --dry-run
```

## Dependencies

- Writing the ISO: `sudo`, `dd`, `lsblk`
- Generating keys: `openssl`, `cert-to-efi-sig-list`, `sign-efi-sig-list`, `uuidgen`

Ubuntu/Debian:
```bash
sudo apt install openssl efitools util-linux
```

Fedora/RHEL:
```bash
sudo dnf install openssl efitools util-linux
```

## Full Documentation

See: `docs/SECUREBOOT_BOOTABLE_MEDIA.md`

