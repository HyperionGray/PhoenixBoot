# Migration Guide: Old Multi-Step Media Workflow → Sanity Mode

PhoenixBoot now ships a sanity-first bootable media workflow:

- optionally (re)generate SecureBoot keys (PK/KEK/db) + enrollment files
- write your OS installer ISO directly to a USB drive you select

## Quick Migration

### Old Way (Many Steps)

```bash
./pf.py secure-keygen
./pf.py secure-make-auth
./pf.py build-setup
./pf.py build-build
# …ESP packaging / USB prep scripts…
```

### New Way (One Command)

```bash
./create-secureboot-bootable-media.sh --iso /path/to.iso --usb-device /dev/sdX
# (or: ./pf.py secureboot-create-usb iso_path=/path/to.iso usb_device=/dev/sdX)
```

## Key Differences

- The script **does not** build a custom “ISO-in-an-ESP” image anymore.
- It **writes the ISO directly** (no loop mounts, no FAT sizing, no “ISO fits?” guessing).
- It can still manage keys:
  - `keys/` (PK/KEK/db)
  - `out/securevars/` (`*.auth`)

## Using Existing Keys vs New Keys

```bash
# Reuse existing keys (generate only if missing)
./create-secureboot-bootable-media.sh --iso /path/to.iso --usb-device /dev/sdX --reuse-keys

# Force brand-new keys (backs up existing keys first)
./create-secureboot-bootable-media.sh --iso /path/to.iso --usb-device /dev/sdX --new-keys

# Skip keys entirely (just write the ISO)
./create-secureboot-bootable-media.sh --iso /path/to.iso --usb-device /dev/sdX --skip-keys
```

## If You Still Need ESP Artifacts

For PhoenixBoot ESP images (QEMU testing, enrollment media, etc.), use:

```bash
./pf.py build-package-esp
./pf.py secure-package-esp-enroll
```
