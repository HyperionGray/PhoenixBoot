#!/usr/bin/env bash
# Description: Generate comprehensive secure boot setup instructions

set -euo pipefail

DOCS_DIR="${DOCS_DIR:-out/artifacts/docs}"
mkdir -p "$DOCS_DIR"

cat > "$DOCS_DIR/SECURE_BOOT_SETUP.md" << 'EOFMARKER'
# PhoenixGuard Secure Boot Setup Instructions

## Overview
This guide walks you through setting up PhoenixGuard with Secure Boot enabled.

## Prerequisites
- UEFI-capable system
- Secure Boot support in firmware
- PhoenixGuard artifacts (ESP image, keys, binaries)
- USB drive or CD/DVD for boot media

## Step 1: Prepare Boot Media

### Option A: USB Drive
1. Insert USB drive (will be erased!)
2. Identify device: `lsblk` (e.g., /dev/sdb)
3. Write ESP image:
   ```bash
   sudo dd if=out/artifacts/esp/esp.img of=/dev/sdX bs=4M status=progress
   sudo sync
   ```

### Option B: CD/DVD
1. Use CD burning software
2. Burn PhoenixGuard-SecureBoot.iso
3. Verify checksum after burning

## Step 2: Boot to Firmware Setup
1. Insert boot media
2. Restart system
3. Press firmware key (F2, Del, F12, etc.)
4. Navigate to Boot or Security settings

## Step 3: Clear Existing Secure Boot Keys (Optional)
⚠️ Only if you want to use custom PhoenixGuard keys:
1. Enter "Secure Boot" settings
2. Select "Clear Secure Boot Keys" or "Delete all keys"
3. System enters "Setup Mode"
4. Save and exit

## Step 4: Enroll PhoenixGuard Keys

### Method A: Using KeyEnrollEdk2.efi (Automated)
1. Boot from PhoenixGuard media
2. Select KeyEnrollEdk2.efi from boot menu
3. Keys will be enrolled automatically
4. System reboots

### Method B: Manual Enrollment (If automated fails)
1. Copy keys from boot media to ESP partition:
   - PK/PK.auth
   - KEK/KEK.auth
   - db/db.auth
2. Boot to firmware setup
3. Navigate to Secure Boot -> Key Management
4. Enroll each key in order:
   - First: db key (signature database)
   - Second: KEK key (key exchange key)
   - Last: PK key (platform key - locks setup mode)
5. Save and exit

## Step 5: Enable Secure Boot
1. In firmware setup, navigate to Secure Boot
2. Set "Secure Boot" to "Enabled"
3. Set "OS Type" to "Windows UEFI" or "Other OS"
4. Save and exit
5. System reboots

## Step 6: Verify Secure Boot Status
Boot PhoenixGuard and check:
```bash
# On Linux:
mokutil --sb-state
# Should show: SecureBoot enabled

# Using UUEFI:
# Boot UUEFI.efi from boot menu
# Shows Secure Boot status on screen
```

## Step 7: Sign Kernel Modules (Linux)
If running Linux with custom modules:
```bash
# Enroll MOK certificate
sudo mokutil --import keys/mok/PGMOK.der

# Reboot and enroll in MOK Manager (blue screen)
# Enter password set during import

# Sign modules
sudo kmodsign sha256 keys/mok/PGMOK.key keys/mok/PGMOK.der /path/to/module.ko
```

## Troubleshooting

### Secure Boot Won't Enable
- Ensure system is in Setup Mode (all keys cleared)
- Verify key files are valid (.auth format)
- Check firmware logs for errors

### Boot Fails After Enabling Secure Boot
- Check that bootloader is signed with enrolled keys
- Verify ESP contains correct signed binaries
- Boot to firmware and temporarily disable Secure Boot
- Re-check key enrollment

### Modules Won't Load
- Ensure MOK is enrolled
- Verify module signature: `modinfo module.ko | grep sig`
- Re-sign module if signature missing

## Security Notes
- Keep private keys (.key files) secure and backed up
- Never share private keys
- Store backup on encrypted external media
- Consider using hardware security module (HSM) for production

## Additional Resources
- PhoenixGuard Documentation: docs/SECURE_BOOT.md
- UEFI Specification: https://uefi.org/specifications
- Linux Secure Boot: https://www.kernel.org/doc/html/latest/admin-guide/module-signing.html
EOFMARKER

echo "✅ Secure Boot instructions created in $DOCS_DIR/SECURE_BOOT_SETUP.md"
echo "   View with: cat $DOCS_DIR/SECURE_BOOT_SETUP.md"
