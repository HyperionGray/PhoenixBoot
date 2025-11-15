# Testing Guide for SecureBoot Bootable Media Creator

This document describes how to test the turnkey SecureBoot bootable media creator.

## Quick Smoke Tests

### 1. Syntax Check
```bash
bash -n create-secureboot-bootable-media.sh
# Should return with no errors
```

### 2. Shellcheck (if available)
```bash
shellcheck create-secureboot-bootable-media.sh
# Should return with no warnings
```

### 3. Help Output
```bash
./create-secureboot-bootable-media.sh --help
# Should display comprehensive help text
```

### 4. Missing ISO Error
```bash
./create-secureboot-bootable-media.sh
# Should error: "ISO path required"
```

### 5. Non-existent ISO Error
```bash
./create-secureboot-bootable-media.sh --iso /tmp/nonexistent.iso
# Should error: "ISO file not found"
```

### 6. Dependency Check
```bash
# Create a minimal test ISO
dd if=/dev/zero of=/tmp/test.iso bs=1M count=1

./create-secureboot-bootable-media.sh --iso /tmp/test.iso
# Should check dependencies and report any missing tools
```

## Full Integration Tests

### Test 1: Key Generation
```bash
# Start fresh
rm -rf keys/ out/

# Run with a test ISO
./create-secureboot-bootable-media.sh --iso /tmp/test.iso

# Verify keys were created
ls keys/PK.key keys/PK.crt keys/KEK.key keys/KEK.crt keys/db.key keys/db.crt
# All should exist

# Verify key format
openssl x509 -in keys/PK.crt -text -noout | grep "Subject: CN = PhoenixGuard PK"
# Should show correct subject
```

### Test 2: Auth File Creation
```bash
# After Test 1, check auth files
ls out/securevars/PK.auth out/securevars/KEK.auth out/securevars/db.auth
# All should exist
```

### Test 3: ESP Creation
```bash
# After Test 1, check ESP image
ls -lh out/esp/secureboot-bootable.img
# Should exist and be appropriately sized

# Verify ESP is FAT32
file out/esp/secureboot-bootable.img | grep "FAT"
# Should show FAT filesystem
```

### Test 4: ESP Content Verification
```bash
# Mount the ESP image (requires sudo)
sudo mkdir -p /mnt/test-esp
sudo mount -o loop out/esp/secureboot-bootable.img /mnt/test-esp

# Check required files
ls /mnt/test-esp/EFI/BOOT/BOOTX64.EFI
ls /mnt/test-esp/EFI/BOOT/grub.cfg
ls /mnt/test-esp/EFI/PhoenixGuard/keys/pk.auth
ls /mnt/test-esp/ISO/test.iso

# Verify GRUB config includes ISO
grep "test.iso" /mnt/test-esp/EFI/BOOT/grub.cfg

# Cleanup
sudo umount /mnt/test-esp
sudo rmdir /mnt/test-esp
```

### Test 5: Existing Keys (Skip Generation)
```bash
# Use existing keys from Test 1
./create-secureboot-bootable-media.sh --iso /tmp/test.iso --skip-keys

# Should use existing keys without regeneration
# Check timestamps - keys should not be newer
```

### Test 6: Different ISO Sizes
```bash
# Test with different ISO sizes to verify ESP sizing

# 10 MB ISO
dd if=/dev/zero of=/tmp/small.iso bs=1M count=10
./create-secureboot-bootable-media.sh --iso /tmp/small.iso
ls -lh out/esp/secureboot-bootable.img
# Should be ~256-300 MB (10 MB + overhead)

# 1 GB ISO (if space available)
dd if=/dev/zero of=/tmp/large.iso bs=1M count=1024
./create-secureboot-bootable-media.sh --iso /tmp/large.iso
ls -lh out/esp/secureboot-bootable.img
# Should be ~1.2-1.5 GB (1 GB + overhead)
```

## QEMU Boot Test (Advanced)

```bash
# Install QEMU and OVMF if not present
sudo apt install qemu-system-x86 ovmf

# Create a copy of OVMF vars (don't modify the original)
cp /usr/share/OVMF/OVMF_VARS.fd /tmp/test_vars.fd

# Boot the image in QEMU (without SecureBoot first)
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=/tmp/test_vars.fd \
  -drive format=raw,file=out/esp/secureboot-bootable.img \
  -nographic

# You should see the GRUB menu
# Press Ctrl+A then X to exit QEMU
```

## Real Hardware Test (Recommended)

### Prerequisites
- USB flash drive (will be erased!)
- Computer with UEFI firmware
- Real ISO (e.g., Ubuntu, Debian)

### Steps
1. Create bootable media with real ISO:
   ```bash
   ./create-secureboot-bootable-media.sh --iso /path/to/ubuntu-22.04.iso
   ```

2. Write to USB:
   ```bash
   # Find USB device (usually /dev/sdb, /dev/sdc)
   lsblk
   
   # Write (DANGEROUS - double check device!)
   sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress conv=fsync
   sync
   ```

3. Boot from USB:
   - Restart computer
   - Enter boot menu (F12, F11, or Esc depending on system)
   - Select USB device
   - You should see GRUB menu

4. Test Easy Mode:
   - Enable SecureBoot in BIOS
   - Boot from USB
   - Select "Boot from ISO"
   - ISO should boot successfully

5. Test Secure Mode:
   - Boot from USB with SecureBoot disabled
   - Select "Enroll PhoenixGuard SecureBoot Keys"
   - Reboot and enable SecureBoot in BIOS
   - Boot from USB again
   - Select "Boot from ISO"
   - ISO should boot with custom keys

## Expected Results

All tests should pass with:
- ✅ No syntax errors
- ✅ No shellcheck warnings
- ✅ Proper error messages for invalid input
- ✅ Keys generated correctly
- ✅ Auth files created
- ✅ ESP image created with correct size
- ✅ All required files on ESP
- ✅ GRUB boots in QEMU
- ✅ Real hardware boot works

## Troubleshooting Tests

### Missing Dependencies
If tests fail due to missing dependencies:
```bash
# Ubuntu/Debian
sudo apt install openssl dosfstools sbsigntool efitools qemu-system-x86 ovmf

# Fedora/RHEL
sudo dnf install openssl dosfstools sbsigntools efitools qemu-system-x86 edk2-ovmf

# Arch
sudo pacman -S openssl dosfstools sbsigntools efitools qemu-system-x86 edk2-ovmf
```

### Permission Errors
Some operations require sudo (mounting, writing to USB). Run with appropriate privileges.

### ESP Too Small
If your ISO is very large (>10 GB), you may need to increase `OVERHEAD_MB` in the script.

## Test Results Template

```
Test Environment:
- OS: Ubuntu 22.04
- Kernel: 5.15.0
- Tools: openssl 3.0, sbsigntool 0.9

Test Results:
[ ] Syntax check passed
[ ] Shellcheck clean
[ ] Help text displays
[ ] Error handling works
[ ] Dependencies checked
[ ] Keys generated
[ ] Auth files created
[ ] ESP image created
[ ] ESP content correct
[ ] QEMU boot successful
[ ] Real hardware boot successful

Notes:
(Any issues or observations)
```

## Continuous Testing

For ongoing development, consider:
1. Add these tests to CI/CD pipeline
2. Test with multiple ISO types (Ubuntu, Debian, Fedora, etc.)
3. Test on different hardware (various UEFI implementations)
4. Test with different SecureBoot configurations
5. Automated regression testing

## Reporting Issues

If tests fail, report with:
1. Test that failed
2. Error message
3. System information (OS, kernel, tools versions)
4. Steps to reproduce
5. Expected vs actual behavior
