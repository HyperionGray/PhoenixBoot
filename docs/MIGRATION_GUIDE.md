# Migration Guide: Old Workflow → New Turnkey Script

This guide helps existing PhoenixBoot users migrate from the old multi-step workflow to the new turnkey SecureBoot bootable media creator.

## Overview

If you've been using the old `.pf` task files to create bootable media, this guide will help you transition to the simpler, one-command approach.

## Quick Migration

### What You Were Doing (Old Way)

```bash
# Old workflow - multiple steps
./pf.py secure-keygen
./pf.py secure-make-auth
./pf.py build-setup
./pf.py build-build
ISO_PATH=/path/to.iso ./pf.py build-package-esp-iso
./pf.py valid-esp-secure
./pf.py verify-esp-robust
USB1_DEV=/dev/sdb ./pf.py usb-prepare
```

### What You Should Do Now (New Way)

```bash
# New workflow - one command
./create-secureboot-bootable-media.sh --iso /path/to.iso

# Optional: Write directly to USB
./create-secureboot-bootable-media.sh --iso /path/to.iso --usb-device /dev/sdb
```

## Key Differences

| Aspect | Old Way | New Way |
|--------|---------|---------|
| Commands | 8-10 separate | 1 command |
| Key generation | Manual (`secure-keygen`) | Automatic |
| Auth files | Manual (`secure-make-auth`) | Automatic |
| ESP creation | Manual (`build-package-esp-iso`) | Automatic |
| Validation | Manual (`valid-esp-secure`) | Automatic |
| USB writing | Manual (`usb-prepare`) | Optional automatic |
| Instructions | Read multiple docs | On the media |
| Error messages | Generic | Specific with solutions |

## What Stays the Same

- ✅ Same key format (PK, KEK, db)
- ✅ Same ESP structure
- ✅ Same boot chain (shim → GRUB → ISO)
- ✅ Same security level
- ✅ Compatible with existing keys

## Using Existing Keys

If you already have keys from the old workflow:

```bash
# Your existing keys in keys/ will be used automatically
./create-secureboot-bootable-media.sh --iso ubuntu.iso --skip-keys

# The script detects and uses existing keys
```

**Compatible key locations:**
- `keys/PK.key`, `keys/PK.crt`
- `keys/KEK.key`, `keys/KEK.crt`
- `keys/db.key`, `keys/db.crt`

## Common Migration Scenarios

### Scenario 1: You Have Existing Keys

**Old workflow:**
```bash
# Keys already generated
ISO_PATH=/path/to.iso ./pf.py build-package-esp-iso
USB1_DEV=/dev/sdb ./pf.py usb-prepare
```

**New workflow:**
```bash
# Use existing keys
./create-secureboot-bootable-media.sh --iso /path/to.iso --skip-keys
```

### Scenario 2: Fresh Start

**Old workflow:**
```bash
./pf.py secure-keygen
./pf.py secure-make-auth
# ... more steps
```

**New workflow:**
```bash
# Everything is automatic
./create-secureboot-bootable-media.sh --iso /path/to.iso
```

### Scenario 3: Multiple ISOs

**Old workflow:**
```bash
# Repeat entire process for each ISO
ISO_PATH=/path/to/ubuntu.iso ./pf.py build-package-esp-iso
# ... more steps
ISO_PATH=/path/to/debian.iso ./pf.py build-package-esp-iso
# ... more steps
```

**New workflow:**
```bash
# Same keys, different ISOs
./create-secureboot-bootable-media.sh --iso ubuntu.iso --skip-keys
./create-secureboot-bootable-media.sh --iso debian.iso --skip-keys
```

### Scenario 4: Automated Builds

**Old workflow:**
```bash
#!/bin/bash
set -e
./pf.py secure-keygen || true
./pf.py secure-make-auth
./pf.py build-setup
# ... more commands
```

**New workflow:**
```bash
#!/bin/bash
set -e
./create-secureboot-bootable-media.sh --iso "$1" --skip-keys --force
```

## File Locations

### Old Locations Still Work

```
keys/                    # Your keys (unchanged)
out/staging/             # Build artifacts (still used)
out/esp/esp.img          # Old ESP image location
```

### New Locations

```
out/esp/secureboot-bootable.img    # New default name
FIRST_BOOT_INSTRUCTIONS.txt        # Instructions (new)
docs/SECUREBOOT_QUICKSTART.md           # Quick reference (new)
```

## What to Keep

✅ **Keep:**
- Your `keys/` directory
- Backup of keys
- Documentation of your key hierarchy
- Any custom `.pf` tasks you created

❌ **Can remove:**
- Custom build scripts that duplicate new functionality
- Multiple step checklists
- Complex USB preparation scripts

## Task File Integration

### Old Tasks Still Available

The old `.pf` tasks still exist and work:
```bash
# Old tasks work (via pfy if you have it installed)
./pf.py secure-keygen
./pf.py build-package-esp
```

### New Tasks Added

```bash
# New simplified tasks
./pf.py secureboot-create          # With ISO_PATH env
./pf.py secureboot-create-usb      # With ISO_PATH and USB_DEVICE
./pf.py secureboot-help            # Show help
```

Or just use the script directly:
```bash
./create-secureboot-bootable-media.sh --iso ubuntu.iso
```

## Breaking Changes

⚠️ **None!** The new script is purely additive. Old workflows continue to work.

However, we recommend migrating to the new script because:
- Much simpler to use
- Better error messages
- Includes instructions on media
- Actively maintained
- More user-friendly

## Troubleshooting Migration

### "Keys not found"

**Problem:** Script can't find your existing keys

**Solution:**
```bash
# Ensure keys are in the expected location
ls keys/PK.key keys/KEK.key keys/db.key

# If they're elsewhere, copy them:
cp /path/to/your/keys/* keys/
```

### "Different output location"

**Problem:** You expect output at `out/esp/esp.img` but it's at `out/esp/secureboot-bootable.img`

**Solution:**
```bash
# Create a symlink for compatibility
ln -s secureboot-bootable.img out/esp/esp.img
```

### "Custom modifications lost"

**Problem:** You had custom modifications to the old workflow

**Solution:**
- Review the new script: `create-secureboot-bootable-media.sh`
- It's well-commented and modular
- Add your customizations or request features via GitHub issues

### "pfy/pf not found"

**Problem:** The old task runner isn't available

**Solution:**
```bash
# Use the script directly (no task runner needed!)
./create-secureboot-bootable-media.sh --iso ubuntu.iso
```

## Documentation Updates

### Old Docs

- Still available for reference
- May contain outdated multi-step procedures

### New Docs (Read These)

1. **Quick Start:** `docs/SECUREBOOT_QUICKSTART.md`
2. **Full Guide:** `docs/SECUREBOOT_BOOTABLE_MEDIA.md`
3. **Comparison:** `docs/BEFORE_AND_AFTER.md`
4. **Testing:** `docs/TESTING_GUIDE.md`
5. **Security:** `docs/SECURITY_CONSIDERATIONS.md`

## Best Practices for Migration

1. **Test First**
   - Try the new script with a test ISO
   - Verify it works in QEMU
   - Then test on real hardware

2. **Keep Backups**
   - Back up your existing keys
   - Save your current ESP images
   - Document what worked for you

3. **Update Scripts**
   - Update any automation to use new script
   - Simplify your build processes
   - Remove unnecessary complexity

4. **Share Feedback**
   - Report any issues on GitHub
   - Suggest improvements
   - Help improve documentation

## Getting Help

If you have issues migrating:

1. **Read the docs:**
   - `docs/SECUREBOOT_QUICKSTART.md` for quick reference
   - `docs/SECUREBOOT_BOOTABLE_MEDIA.md` for details

2. **Check examples:**
   - `docs/BEFORE_AND_AFTER.md` shows old vs new

3. **Test thoroughly:**
   - `docs/TESTING_GUIDE.md` has test procedures

4. **Ask for help:**
   - Open a GitHub issue
   - Tag it with `migration` label
   - Include your old workflow

## Migration Checklist

Use this checklist to track your migration:

- [ ] Read migration guide
- [ ] Back up existing keys
- [ ] Test new script with test ISO
- [ ] Verify keys are compatible
- [ ] Test in QEMU
- [ ] Test on real hardware
- [ ] Update automation scripts
- [ ] Update documentation
- [ ] Share feedback

## Example Migration Script

Here's a complete migration example:

```bash
#!/bin/bash
# migrate-to-new-workflow.sh - Helper script for migration

set -euo pipefail

echo "PhoenixBoot Migration Helper"
echo "============================"
echo ""

# 1. Check for existing keys
if [ -f keys/PK.key ]; then
    echo "✓ Found existing keys"
    USE_EXISTING="--skip-keys"
else
    echo "ℹ No existing keys found, will generate new ones"
    USE_EXISTING=""
fi

# 2. Get ISO path
if [ -z "${1:-}" ]; then
    echo "Usage: $0 /path/to.iso [/dev/sdX]"
    exit 1
fi
ISO_PATH="$1"
USB_DEVICE="${2:-}"

# 3. Run new script
echo ""
echo "Running new turnkey script..."
if [ -n "$USB_DEVICE" ]; then
    ./create-secureboot-bootable-media.sh \
        --iso "$ISO_PATH" \
        $USE_EXISTING \
        --usb-device "$USB_DEVICE"
else
    ./create-secureboot-bootable-media.sh \
        --iso "$ISO_PATH" \
        $USE_EXISTING
fi

echo ""
echo "✓ Migration complete!"
echo ""
echo "Output: out/esp/secureboot-bootable.img"
echo "Instructions: FIRST_BOOT_INSTRUCTIONS.txt"
echo ""
echo "Next steps:"
echo "  1. Read FIRST_BOOT_INSTRUCTIONS.txt"
if [ -z "$USB_DEVICE" ]; then
    echo "  2. Write to USB: sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M"
fi
echo "  3. Boot from USB and follow instructions"
```

Save this as `migrate-to-new-workflow.sh` and use:
```bash
chmod +x migrate-to-new-workflow.sh
./migrate-to-new-workflow.sh /path/to/ubuntu.iso
```

## Success Stories

> "Migrated in 5 minutes. So much easier now!" - Future User

> "Kept my existing keys, works perfectly!" - Future User

> "Why didn't we do this sooner?" - Future User

## Conclusion

The new turnkey script dramatically simplifies SecureBoot bootable media creation while maintaining full compatibility with your existing keys and workflows.

**Benefits of migrating:**
- ✅ 90% fewer commands
- ✅ Much simpler to use
- ✅ Better error messages
- ✅ Instructions included on media
- ✅ Actively maintained
- ✅ Well documented

**No downsides:**
- ❌ Old workflows still work
- ❌ No breaking changes
- ❌ Keys are compatible
- ❌ Same security level

Start using the new script today for a much better experience! 🔥
