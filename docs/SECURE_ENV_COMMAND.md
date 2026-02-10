# PhoenixBoot secure_env Command

## Overview

The `secure_env` command is a comprehensive security environment checker that validates the integrity and security of your system's boot process, kernel configuration, and EFI/UEFI environment. It's designed to detect bootkits, rootkits, and other low-level security threats while ensuring proper SecureBoot configuration and kernel hardening.

## Features

### 1. **UEFI/EFI Environment Check**
- Verifies system is running in UEFI mode
- Checks accessibility of EFI variables
- Validates EFI variable count and integrity

### 2. **Secure Boot Status**
- Checks if Secure Boot is enabled
- Validates bootloader configuration (shim, BOOTX64.efi)
- Identifies ESP (EFI System Partition) location
- Verifies Secure Boot variable presence (PK, KEK, db, dbx)

### 3. **EFI Variables Security**
- Scans for suspicious EFI variable modifications
- Integrates with UEFI variable analyzer
- Checks critical Secure Boot variables

### 4. **Boot Integrity Verification**
- Validates kernel module signature enforcement
- Checks kernel lockdown mode (integrity/confidentiality)
- Verifies GRUB bootloader configuration
- Checks for GRUB password protection
- Validates initramfs integrity

### 5. **Kernel Security Features**
- Analyzes kernel configuration for security options
- Checks for:
  - Module signature verification (`CONFIG_MODULE_SIG`)
  - Forced signature verification (`CONFIG_MODULE_SIG_FORCE`)
  - Kernel lockdown LSM (`CONFIG_SECURITY_LOCKDOWN_LSM`)
  - Strict kernel RWX permissions (`CONFIG_STRICT_KERNEL_RWX`)
  - KASLR (`CONFIG_RANDOMIZE_BASE`)
  - Hardened usercopy (`CONFIG_HARDENED_USERCOPY`)

### 6. **Bootkit Detection**
- Integrates with PhoenixBoot's bootkit detection engine
- Compares running firmware against baseline
- Identifies suspicious modifications
- Risk assessment (CRITICAL, HIGH, MEDIUM, LOW)

### 7. **Kernel Module Signature Verification**
- Scans kernel modules for valid signatures
- Reports unsigned module percentage
- Checks for PhoenixGuard MOK enrollment
- Provides guidance for module signing

### 8. **Attack Vector Analysis**
- Analyzes boot parameters for dangerous options
- Detects potential rootkit indicators
- Validates firmware file integrity
- Checks for single-user mode or emergency boot attempts

## Usage

### Basic Usage

```bash
# Run via PhoenixBoot task runner
./pf.py secure-env

# Or run directly
bash scripts/secure-env-check.sh
```

### Running with Root Privileges

For complete security checks, run with root/sudo:

```bash
sudo ./pf.py secure-env
# or
sudo bash scripts/secure-env-check.sh
```

**Note**: Some checks (EFI variable analysis, bootkit detection) require root access. The command will still run with limited permissions but will skip certain checks.

### Output

The command generates two types of reports:

1. **Text Report**: Human-readable detailed report
   - Location: `out/reports/secure_env_report_TIMESTAMP.txt`
   - Contains full check results with color-coded status

2. **JSON Report**: Machine-readable summary
   - Location: `out/reports/secure_env_report_TIMESTAMP.json`
   - Includes metrics and security level assessment

## Understanding the Output

### Status Indicators

- `✓` (Green) - **PASS**: Check passed successfully
- `✗` (Red) - **FAIL**: Security issue detected
- `⚠` (Yellow) - **WARNING**: Potential security concern
- `ℹ` (Blue) - **INFO**: Informational message
- `⊘` (Yellow) - **SKIP**: Check skipped (usually due to permissions or unavailable features)

### Severity Levels

Issues are categorized by severity:

- **CRITICAL**: Immediate security threat requiring urgent action
- **HIGH**: Significant security risk that should be addressed soon
- **MEDIUM**: Moderate security concern that should be improved
- **LOW**: Minor security issue or best practice recommendation

### Security Levels

Overall system security is rated as:

- **CRITICAL**: Critical issues detected - immediate action required
- **HIGH RISK**: High-severity issues found - action required
- **MEDIUM RISK**: Multiple medium issues - improvements needed
- **ACCEPTABLE**: Minor issues - improvements suggested
- **GOOD**: System is well hardened

## Addressing Security Issues

### Common Issues and Solutions

#### 1. Secure Boot Disabled

**Issue**: `SecureBoot is DISABLED - system vulnerable to boot-level attacks`

**Solution**:
```bash
# Generate Secure Boot keys
./pf.py secure-keygen

# Create bootable media with SecureBoot
ISO_PATH=/path/to.iso ./pf.py secureboot-create

# Enable SecureBoot in BIOS/UEFI settings
```

#### 2. Kernel Module Signature Enforcement Disabled

**Issue**: `Kernel module signature enforcement is DISABLED`

**Solution**:
```bash
# Generate and enroll PhoenixGuard MOK
./pf.py mok-flow

# Sign kernel modules
PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

#### 3. Kernel Lockdown Disabled

**Issue**: `Kernel lockdown is DISABLED - system vulnerable to attacks`

**Solution**:
```bash
# Add lockdown parameter to GRUB configuration
sudo nano /etc/default/grub
# Add to GRUB_CMDLINE_LINUX: lockdown=integrity

# Update GRUB
sudo update-grub
sudo reboot
```

#### 4. GRUB Password Protection Missing

**Issue**: `GRUB does not have password protection - boot parameters can be modified`

**Solution**:
```bash
# Generate GRUB password hash
grub-mkpasswd-pbkdf2

# Edit GRUB configuration
sudo nano /etc/grub.d/40_custom
# Add:
# set superusers="root"
# password_pbkdf2 root <generated_hash>

# Update GRUB
sudo update-grub
```

#### 5. Bootkit Detection

**Issue**: `No firmware baseline found - bootkit detection limited`

**Solution**:
```bash
# Create firmware baseline and run full scan
bash scripts/scan-bootkits.sh
```

#### 6. Unsigned Kernel Modules

**Issue**: High percentage of unsigned kernel modules

**Solution**:
```bash
# Sign all modules in the current kernel
PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign

# For specific module:
PATH=/lib/modules/$(uname -r)/kernel/drivers/mymodule.ko ./pf.py os-kmod-sign
```

## Integration with PhoenixBoot Workflows

### Complete Security Hardening Workflow

```bash
# 1. Run security environment check
./pf.py secure-env

# 2. Generate Secure Boot keys
./pf.py secure-keygen

# 3. Set up MOK for module signing
./pf.py mok-flow

# 4. Sign kernel modules
PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign

# 5. Create firmware baseline
bash scripts/scan-bootkits.sh

# 6. Run security check again
./pf.py secure-env

# 7. Validate all configurations
./pf.py verify
```

### Automated Security Monitoring

Run `secure-env` regularly to monitor system security:

```bash
# Add to cron for daily checks
0 2 * * * cd /path/to/PhoenixBoot && ./pf.py secure-env >> /var/log/phoenixboot-security.log 2>&1
```

## Exit Codes

The command returns different exit codes based on security status:

- `0`: No critical or high-severity issues
- `1`: High-severity issues detected
- `2`: Critical-severity issues detected

This allows integration with monitoring tools and automation scripts.

## Report Files

### Text Report Format

The text report includes:
- Header with system information
- Detailed check results by category
- Security recommendations
- Summary with issue counts
- Overall security assessment

### JSON Report Format

```json
{
  "timestamp": "2025-11-16T17:36:52+00:00",
  "hostname": "example-host",
  "kernel": "6.11.0-1018-azure",
  "security_level": "HIGH_RISK",
  "checks": {
    "passed": 6,
    "critical_issues": 0,
    "high_issues": 1,
    "medium_issues": 3,
    "low_issues": 0,
    "total_issues": 4
  },
  "reports": {
    "text_report": "/path/to/text_report.txt",
    "log_directory": "/path/to/logs"
  }
}
```

## Related Commands

- `./pf.py secure-keygen` - Generate Secure Boot keys
- `./pf.py mok-flow` - Set up MOK for module signing
- `./pf.py os-kmod-sign` - Sign kernel modules
- `./pf.py verify` - Run all validation checks
- `bash scripts/scan-bootkits.sh` - Full bootkit detection scan
- `./pf.py validate-all` - Validate keys and ESP

## Technical Details

### Check Categories

1. **UEFI/EFI Environment**: Validates UEFI mode and EFI variable access
2. **Secure Boot Status**: Checks Secure Boot enablement and configuration
3. **EFI Variables Security**: Scans for suspicious variable modifications
4. **Boot Integrity**: Validates bootloader and boot chain integrity
5. **Kernel Security**: Analyzes kernel hardening features
6. **Bootkit Detection**: Compares firmware against baseline
7. **Module Signatures**: Verifies kernel module signing
8. **Attack Vectors**: Checks for common attack patterns

### Dependencies

- `bash` 4.0+
- `python3` (for bootkit detection and UEFI analysis)
- `mokutil` (optional, for Secure Boot status)
- `modinfo` (for module signature checking)
- Root access (recommended for complete checks)

### Files Created

- `out/reports/secure_env_report_TIMESTAMP.txt` - Detailed text report
- `out/reports/secure_env_report_TIMESTAMP.json` - JSON summary
- `out/logs/uefi_vars_TIMESTAMP.log` - UEFI variable analysis (if run)
- `out/logs/bootkit_scan_TIMESTAMP.json` - Bootkit scan results (if run)
- `out/logs/mok_list_TIMESTAMP.txt` - MOK enrollment status

## Best Practices

1. **Run regularly**: Schedule regular security checks (daily or weekly)
2. **Use root access**: Run with sudo for complete checks
3. **Address issues promptly**: Fix CRITICAL and HIGH severity issues immediately
4. **Create baselines**: Establish firmware baseline for accurate bootkit detection
5. **Keep keys secure**: Protect Secure Boot and MOK private keys
6. **Monitor changes**: Review security reports and track improvements
7. **Integrate with CI/CD**: Include security checks in deployment pipelines

## Troubleshooting

### "System is NOT running in UEFI mode"

**Cause**: System booted in legacy BIOS mode

**Solution**: Configure BIOS/UEFI to boot in UEFI mode, not legacy/CSM mode

### "Cannot determine Secure Boot state"

**Cause**: `mokutil` not installed or not accessible

**Solution**:
```bash
# Ubuntu/Debian
sudo apt install mokutil

# Fedora/RHEL
sudo dnf install mokutil

# Arch
sudo pacman -S mokutil
```

### "EFI variables not accessible"

**Cause**: Running without sufficient permissions or efivars not mounted

**Solution**:
```bash
# Check if efivars is mounted
mount | grep efivars

# Mount efivars (as root)
sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars

# Run check with sudo
sudo ./pf.py secure-env
```

### "Bootkit detection requires root access"

**Cause**: Firmware analysis requires privileged access

**Solution**:
```bash
sudo ./pf.py secure-env
# or
sudo bash scripts/secure-env-check.sh
```

## See Also

- [PhoenixBoot README](../README.md)
- [Secure Boot Setup Guide](./SECUREBOOT_QUICKSTART.md)
- [Boot Security Analysis](BOOT_SEQUENCE_AND_ATTACK_SURFACES.md)
- [Firmware Recovery](FIRMWARE_RECOVERY.md)

---

**Security Note**: The `secure_env` command is designed to detect and report security issues. It does not automatically fix issues to avoid unintended system modifications. Always review recommendations before applying changes.
