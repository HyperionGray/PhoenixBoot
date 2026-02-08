# 🔥 SecureBoot Bootable Media (Sanity Mode)

This guide covers the simplest, most reliable workflow:

1. (Optional) generate your SecureBoot key hierarchy (PK/KEK/db) + enrollment files
2. write an OS installer ISO directly to a USB drive you choose

No custom ESP images, no loop-mounting, no ISO “fits in FAT” math.

## Quick Start

```bash
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso --usb-device /dev/sdX
# (or: ./pf.py secureboot-create-usb iso_path=/path/to/ubuntu.iso usb_device=/dev/sdX)
```

The script will:
- ask whether you want to generate new SecureBoot keys
- confirm before erasing the target device
- preflight-check that the USB is large enough
- write the ISO with progress output

## Keys and Enrollment Files

If you choose to generate keys:

- Keys are written to `keys/` (private `.key` files + public certs)
- Enrollment files are written to `out/securevars/` (`PK.auth`, `KEK.auth`, `db.auth`)

Back up `keys/` securely. Those private keys control what your firmware will trust.

## Troubleshooting

- **“Refusing to write to non-disk device”**: pass the whole-disk path like `/dev/sdX` (not `/dev/sdX1`).
- **“USB device is too small”**: use a larger drive or a smaller ISO.
- **ISO won’t boot after writing**: some ISOs aren’t hybrid images; use Rufus/Etcher for that ISO.

## Advanced (If You Need It)

If you’re building PhoenixBoot ESP artifacts (QEMU testing, enrollment media, etc.), use:

```bash
./pf.py build-package-esp
./pf.py secure-package-esp-enroll
```
