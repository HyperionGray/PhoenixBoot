# Kernel Hardening and UEFI Security Guide

## Overview

PhoenixBoot provides comprehensive kernel hardening analysis and UEFI variable security checks based on DISA STIG standards and industry best practices. This guide covers:

1. **Kernel Configuration Hardening** - Analyze and harden kernel configs against DISA STIG
2. **UEFI Variable Checks** - Verify Secure Boot status and firmware integrity
3. **Firmware Checksum Database** - Validate firmware against known-good checksums
4. **Kernel Config Remediation** - Fix kernel configs using kexec double-jump technique

## Quick Start

### Check Your System Security

```bash
# Comprehensive security check (includes all checks)
./pf.py secure-env

# Kernel hardening analysis only
./pf.py kernel-hardening-check

# Generate detailed reports
./pf.py kernel-hardening-report
```

### Analyze Kernel Configuration

```bash
# Analyze current kernel config
./pf.py kernel-hardening-check

# Generate detailed report
./pf.py kernel-hardening-report
# Output: out/reports/kernel_hardening_report.txt
#         out/reports/kernel_hardening_report.json

# Generate hardened baseline config
./pf.py kernel-hardening-baseline
# Output: out/baselines/hardened_kernel.config
```

### Compare and Remediate Kernel Config

```bash
# Show differences from hardened baseline
./pf.py kernel-config-diff

# Generate remediation script
./pf.py kernel-config-remediate
# Output: out/remediation/kernel_remediation.sh

# Check if kexec is available for remediation
./pf.py kernel-kexec-check

# View kexec double-jump workflow guide
./pf.py kernel-kexec-guide
```

### Verify Firmware Checksums

```bash
# List firmware checksums in database
./pf.py firmware-checksum-list

# Verify a firmware file
FIRMWARE_PATH=/path/to/firmware.bin ./pf.py firmware-checksum-verify

# Add firmware to database
FIRMWARE_PATH=/path/to/firmware.bin \
  VENDOR="ASUS" \
  MODEL="ROG X570-E" \
  VERSION="4021" \
  ./pf.py firmware-checksum-add
```

## Kernel Hardening Features

### Security Checks Based On

- **DISA STIG** (Security Technical Implementation Guide) for Red Hat Enterprise Linux
- **Linux Kernel Self Protection Project (KSPP)**
- **CIS Benchmarks**
- **NSA Kernel Hardening Guidelines**

### Categories Analyzed

#### 1. Boot Security
- `CONFIG_SECURITY_LOCKDOWN_LSM` - Prevents runtime kernel modifications
- `CONFIG_MODULE_SIG` - Kernel module signature verification
- `CONFIG_MODULE_SIG_FORCE` - Require all modules to be validly signed
- `CONFIG_KEXEC` - Disable kexec (can bypass secure boot)
- `CONFIG_HIBERNATION` - Disable hibernation (data leak risk)

#### 2. Memory Protection
- `CONFIG_STRICT_KERNEL_RWX` - Mark kernel memory as read-only or non-executable
- `CONFIG_HARDENED_USERCOPY` - Harden kernel/userspace data copying
- `CONFIG_PAGE_TABLE_ISOLATION` - Isolate kernel page tables (Meltdown mitigation)
- `CONFIG_RANDOMIZE_BASE` - Kernel Address Space Layout Randomization (KASLR)
- `CONFIG_SLAB_FREELIST_RANDOM` - Randomize slab allocator

#### 3. Stack Protection
- `CONFIG_STACKPROTECTOR_STRONG` - Strong stack canary protection
- `CONFIG_VMAP_STACK` - Use virtually-mapped kernel stacks

#### 4. Access Control
- `CONFIG_SECURITY_SELINUX` - Enable SELinux
- `CONFIG_SECURITY_APPARMOR` - Enable AppArmor
- `CONFIG_SECURITY_YAMA` - Yama LSM (ptrace restrictions)

#### 5. Debug Features (should be disabled in production)
- `CONFIG_DEBUG_FS` - Disable debugfs (exposes kernel internals)
- `CONFIG_KPROBES` - Disable kprobes (rootkit risk)
- `CONFIG_PROC_KCORE` - Disable /proc/kcore (exposes kernel memory)

#### 6. Network Security
- `CONFIG_SYN_COOKIES` - Enable SYN cookie protection

#### 7. Hardware Access
- `CONFIG_STRICT_DEVMEM` - Restrict /dev/mem access
- `CONFIG_DEVMEM` - Completely disable /dev/mem (most secure)

## Understanding Security Reports

### Security Levels

The analyzer assigns an overall security level:

- **EXCELLENT** (90-100%): Outstanding kernel hardening
- **GOOD** (75-89%): Well-configured security
- **ACCEPTABLE** (50-74%): Basic security, improvements recommended
- **POOR** (<50%): Critical security issues, immediate action required

### Severity Classifications

- **CRITICAL**: Immediate security threat, must fix
- **HIGH**: Significant risk, should fix soon
- **MEDIUM**: Moderate concern, recommended to fix
- **LOW**: Minor issue, best practice recommendation

### Example Report Output

```
================================================================================
PhoenixBoot Kernel Hardening Analysis Report
================================================================================

Kernel Config: /boot/config-6.11.0-1018-azure
Security Score: 72/100 (ACCEPTABLE)
Checks Passed: 36/50
Checks Failed: 14/50

================================================================================
Summary by Category
================================================================================

Boot Security:
  Passed: 4/6 (66%)

Memory Protection:
  Passed: 8/9 (88%)

Stack Protection:
  Passed: 3/3 (100%)

================================================================================
Failed Security Checks
================================================================================

CRITICAL Severity:

  ✗ CONFIG_MODULE_SIG_FORCE
    Category:    Boot Security
    Expected:    y
    Actual:      n
    Description: Require all kernel modules to be validly signed
    STIG ID:     RHEL-08-010370
    Remediation: Enable CONFIG_MODULE_SIG_FORCE=y

HIGH Severity:

  ✗ CONFIG_KEXEC
    Category:    Boot Security
    Expected:    n
    Actual:      y
    Description: Disable kexec (can bypass secure boot)
    STIG ID:     RHEL-08-010372
    Remediation: Disable CONFIG_KEXEC unless specifically needed
```

## Kernel Config Remediation

### Overview

PhoenixBoot supports two methods for kernel config remediation:

1. **Traditional Method**: Edit config, rebuild, reboot
2. **kexec Double-Jump**: Edit config without full reboot (advanced)

### Traditional Remediation Workflow

```bash
# 1. Generate remediation script
./pf.py kernel-config-remediate

# 2. Review the script
cat out/remediation/kernel_remediation.sh

# 3. Run as root
sudo out/remediation/kernel_remediation.sh

# 4. The script will:
#    - Backup current config
#    - Apply required changes
#    - Update dependencies with 'make olddefconfig'
#    - Provide instructions for building and installing

# 5. Build and install kernel (manual steps)
cd /usr/src/linux-$(uname -r)
make -j$(nproc)
sudo make modules_install
sudo make install
sudo update-grub
sudo reboot
```

### kexec Double-Jump Remediation (Advanced)

The kexec double-jump technique allows kernel remediation without a full system reboot:

```bash
# 1. Check if kexec is available
./pf.py kernel-kexec-check

# 2. View the workflow guide
./pf.py kernel-kexec-guide

# 3. Prepare alternate kernel (signed for Secure Boot)
# You need a working kernel to kexec into

# 4. First kexec into alternate kernel
sudo kexec -l /boot/vmlinuz-alternate --initrd=/boot/initrd-alternate
sudo kexec -e

# 5. System boots into alternate kernel (no full reboot)
# Now modify and rebuild the target kernel

# 6. Apply kernel config changes
sudo out/remediation/kernel_remediation.sh

# 7. Build the modified kernel
cd /usr/src/linux-target
make -j$(nproc)
sudo make modules_install
sudo make install

# 8. kexec back to the modified kernel
sudo kexec -l /boot/vmlinuz-modified --initrd=/boot/initrd-modified
sudo kexec -e
```

### When kexec is Disabled

If kernel hardening disables kexec (`CONFIG_KEXEC=n` or lockdown in confidentiality mode):

**Options:**

1. **Use Traditional Reboot Method**
2. **Temporarily Enable kexec**:
   - Boot with `lockdown=integrity` instead of `lockdown=confidentiality`
   - Or disable `CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY`
3. **Modify Kernel from Installation Media**:
   - Boot from USB/CD
   - Mount system partition
   - Modify kernel config
   - Rebuild and install
   - Reboot into modified kernel

## Firmware Checksum Database

### Purpose

The firmware checksum database stores SHA256, SHA1, and MD5 hashes of known-good firmware images. This enables:

- **Bootkit Detection**: Identify modified firmware
- **Supply Chain Security**: Verify firmware authenticity
- **Firmware Recovery**: Restore known-good firmware

### Database Schema

```sql
firmware_checksums (
    vendor TEXT,
    model TEXT,
    version TEXT,
    sha256 TEXT UNIQUE,
    sha1 TEXT,
    md5 TEXT,
    size INTEGER,
    source TEXT,
    confidence_score INTEGER,
    added_date TEXT,
    notes TEXT
)
```

### Usage Examples

#### List All Firmware

```bash
./pf.py firmware-checksum-list
```

#### Verify Firmware

```bash
# Verify a BIOS/UEFI firmware file
FIRMWARE_PATH=/path/to/bios.bin ./pf.py firmware-checksum-verify

# Example output:
# ✓ VERIFIED: Firmware matches known-good checksum
#   Vendor:     ASUS
#   Model:      ROG Strix X570-E
#   Version:    4021
#   Confidence: 90/100
#   Source:     vendor_official
```

#### Add Firmware to Database

```bash
# Add a firmware file
FIRMWARE_PATH=/downloads/bios_4021.bin \
  VENDOR="ASUS" \
  MODEL="ROG Strix X570-E Gaming" \
  VERSION="4021" \
  SOURCE="vendor_official" \
  CONFIDENCE=90 \
  ./pf.py firmware-checksum-add
```

#### Direct Tool Usage

```bash
# Python tool provides additional features
cd utils

# Export database to JSON
python3 firmware_checksum_db.py --export /tmp/firmware_db.json

# Import from JSON
python3 firmware_checksum_db.py --import /tmp/firmware_db.json

# Search by vendor
python3 firmware_checksum_db.py --search --vendor ASUS

# Search by vendor and model
python3 firmware_checksum_db.py --search --vendor ASUS --model "X570"
```

## UEFI Variable Security Checks

The secure-env-check now includes enhanced UEFI variable analysis:

### Checks Performed

1. **UEFI Mode Verification**
   - Confirms system is running in UEFI mode
   - Checks EFI variable accessibility

2. **Secure Boot Status**
   - Verifies Secure Boot is enabled
   - Checks for bootloader (shim, BOOTX64.efi)
   - Identifies ESP location

3. **Critical Secure Boot Variables**
   - `SecureBoot` - Current Secure Boot state
   - `SetupMode` - Whether in setup or user mode
   - `PK` - Platform Key
   - `KEK` - Key Exchange Key
   - `db` - Signature Database
   - `dbx` - Forbidden Signature Database

4. **Variable Integrity**
   - Scans for suspicious modifications
   - Uses uefi_variable_analyzer.py for deep analysis

### Running UEFI Checks

```bash
# Full security check (includes UEFI analysis)
sudo ./pf.py secure-env

# Results saved to:
# - out/reports/secure_env_report_TIMESTAMP.txt
# - out/reports/secure_env_report_TIMESTAMP.json
# - out/logs/uefi_vars_TIMESTAMP.log
```

## Integration with Existing PhoenixBoot Features

### Secure Boot Key Management

```bash
# Generate Secure Boot keys
./pf.py secure-keygen

# Create authentication variables
./pf.py secure-make-auth
```

### Module Signing

```bash
# Sign kernel modules
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

### Complete Security Hardening Workflow

```bash
# 1. Initial security assessment
sudo ./pf.py secure-env

# 2. Analyze kernel hardening
./pf.py kernel-hardening-report

# 3. Generate remediation plan
./pf.py kernel-config-remediate

# 4. Check kexec availability
./pf.py kernel-kexec-check

# 5. Apply remediation (if kexec available)
sudo out/remediation/kernel_remediation.sh

# 6. Generate Secure Boot keys
./pf.py secure-keygen

# 7. Set up MOK for module signing
./pf.py mok-flow

# 8. Sign kernel modules
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign

# 9. Verify firmware checksums
FIRMWARE_PATH=/sys/firmware/efi ./pf.py firmware-checksum-verify

# 10. Final security verification
sudo ./pf.py secure-env
```

## Best Practices

### Kernel Hardening

1. **Start with Baseline**: Generate hardened baseline and compare
2. **Review Changes**: Don't blindly apply all changes - review each
3. **Test in VM First**: Use QEMU to test before applying to production
4. **Document Exceptions**: If you can't enable an option, document why
5. **Regular Audits**: Run hardening checks regularly (weekly/monthly)

### UEFI Security

1. **Enable Secure Boot**: Critical first step
2. **Use Custom Keys**: Generate your own PK/KEK/db keys
3. **Verify Firmware**: Check checksums after BIOS updates
4. **Monitor Variables**: Regularly check for suspicious modifications
5. **Protect ESP**: Mount /boot/efi read-only when not updating

### Firmware Checksums

1. **Build Database**: Add known-good firmware from vendor sites
2. **High Confidence**: Only add firmware from trusted sources
3. **Regular Updates**: Keep database updated with new firmware versions
4. **Baseline Before Update**: Capture checksum before applying updates
5. **Verify After Update**: Always verify checksum after BIOS updates

### Remediation

1. **Backup First**: Always backup current config before changes
2. **Incremental Changes**: Don't change everything at once
3. **Test Thoroughly**: Boot and test after each major change
4. **Have Recovery Plan**: Keep bootable USB ready
5. **Document Process**: Keep notes on what changed and why

## Troubleshooting

### "Kernel config not found"

Try these locations:
```bash
# Check common locations
ls -l /proc/config.gz
ls -l /boot/config-$(uname -r)

# Extract from running kernel (if compiled in)
zcat /proc/config.gz > /tmp/kernel.config
```

### "kexec not available"

Install kexec-tools:
```bash
# Ubuntu/Debian
sudo apt install kexec-tools

# Fedora/RHEL
sudo dnf install kexec-tools

# Arch
sudo pacman -S kexec-tools
```

### "Kernel lockdown blocks kexec"

Options:
1. Boot with `lockdown=integrity` instead of `lockdown=confidentiality`
2. Disable `CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY` (not recommended for production)
3. Use traditional reboot method

### "Cannot access EFI variables"

Mount efivars:
```bash
# Check if mounted
mount | grep efivars

# Mount if needed
sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars
```

## Reference Documentation

- [DISA STIG for RHEL 8](https://www.stigviewer.com/stig/red_hat_enterprise_linux_8/)
- [Linux Kernel Self Protection Project](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project)
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/red_hat_linux)
- [NSA Hardening Guide](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/3215760/nsa-cisa-release-kubernetes-hardening-guidance/)

## Support

For issues or questions:
- GitHub Issues: https://github.com/P4X-ng/PhoenixBoot/issues
- Documentation: docs/
- Security Checks: `./pf.py secure-env`

---

**Security Note**: These tools are designed for defensive security hardening. Always test changes in a non-production environment first and maintain good backups.
