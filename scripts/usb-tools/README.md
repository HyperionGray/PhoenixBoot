# USB Tools

Scripts for creating and managing bootable USB media.

## USB Preparation

- `usb-prepare.sh` - Prepare USB drive
- `usb-sanitize.sh` - Sanitize USB drive
- `usb-enroll.sh` - Enroll keys on USB media

## USB Operations

- `usb-write-dd.sh` - Write image to USB using dd
- `usb-run.sh` - Run USB-based operations
- `organize-usb1.sh` - Organize USB structure

## Usage

```bash
# Prepare USB drive
sudo ./scripts/usb-tools/usb-prepare.sh

# Write bootable image
sudo ./scripts/usb-tools/usb-write-dd.sh /path/to/image.img /dev/sdX

# Create SecureBoot bootable media from ISO
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso
```
