# Testing Guide: `create-secureboot-bootable-media.sh`

This script is intentionally simple: optional key generation + `dd` the ISO to a selected USB device.

## Quick Smoke Tests

### 1) Syntax check
```bash
bash -n create-secureboot-bootable-media.sh
```

### 2) Help output
```bash
./create-secureboot-bootable-media.sh --help
```

### 3) Missing ISO error
```bash
./create-secureboot-bootable-media.sh --usb-device /dev/sdX
```

### 4) Non-existent ISO error
```bash
./create-secureboot-bootable-media.sh --iso /tmp/nonexistent.iso --usb-device /dev/sdX
```

## Safe Integration Test (Loop Device)

This writes to a loop-backed “USB device” (a file), not real hardware.

```bash
# Create a tiny fake ISO-like file (for write testing only)
dd if=/dev/zero of=/tmp/test.iso bs=1M count=16

# Create a fake 128MiB "USB drive"
dd if=/dev/zero of=/tmp/fake-usb.img bs=1M count=128

# Attach loop device (prints /dev/loopX)
LOOP_DEV=$(sudo losetup -fP --show /tmp/fake-usb.img)

# Dry-run (no write), keys skipped
./create-secureboot-bootable-media.sh --iso /tmp/test.iso --usb-device "$LOOP_DEV" --skip-keys --dry-run

# Real write to loop device (still safe; it’s a file)
./create-secureboot-bootable-media.sh --iso /tmp/test.iso --usb-device "$LOOP_DEV" --skip-keys --yes --verify

# Cleanup
sudo losetup -d "$LOOP_DEV"
```

