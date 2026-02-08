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
# Prepare USB drive (writes the latest out/esp/esp.img and keeps it organized)
sudo ./scripts/usb-tools/usb-prepare.sh --device /dev/sdX

# Sanitize an existing USB (dry-run by default, add --force to mutate)
sudo ./scripts/usb-tools/usb-sanitize.sh --device /dev/sdX --force

# Write an ESP image using dd (explicit confirmation required)
sudo ./scripts/usb-tools/usb-write-dd.sh --device /dev/sdX --image out/esp/esp.img --confirm

# Run the full production workflow (builds artifacts, prepares + sanitizes)
sudo ./scripts/usb-tools/usb-run.sh --device /dev/sdX

# Create SecureBoot bootable media from ISO (wrapper script)
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso --usb-device /dev/sdX
```

`usb-prepare.sh` also accepts `--format TYPE` to reformat the USB partition, `--skip-organize` to leave the drive as-is after copying, and `--no-sync` to skip the final `sync` step when another tool handles that.
