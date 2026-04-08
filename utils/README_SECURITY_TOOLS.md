# PhoenixBoot Utilities

This directory contains Python utility scripts for PhoenixBoot security analysis and hardening.

## New Security Tools

### Kernel Hardening Analyzer (`kernel_hardening_analyzer.py`)

Analyzes kernel configuration against DISA STIG standards and security best practices.

**Features:**
- 50+ security checks based on DISA STIG, KSPP, CIS Benchmarks
- Categories: Boot Security, Memory Protection, Stack Protection, Access Control
- Severity classifications: CRITICAL, HIGH, MEDIUM, LOW
- Security scoring (0-100) with overall assessment
- Generate hardened baseline configurations

**Quick Start:**
```bash
# Analyze current kernel config
python3 kernel_hardening_analyzer.py --auto

# Generate detailed report
python3 kernel_hardening_analyzer.py --auto --output report.txt

# Generate hardened baseline
python3 kernel_hardening_analyzer.py --generate-baseline > hardened.config

# Or use pf.py tasks:
./pf.py kernel-hardening-check
./pf.py kernel-hardening-report
./pf.py kernel-hardening-baseline
```

### Kernel Config Remediation (`kernel_config_remediation.py`)

Compares kernel configs and provides remediation through traditional or kexec methods.

**Features:**
- Compare current config against hardened baseline
- Generate remediation scripts
- Support for kexec double-jump technique
- Handle kernel lockdown modes
- Graceful fallback when kexec is disabled

**Quick Start:**
```bash
# Show configuration differences
python3 kernel_config_remediation.py --current /boot/config-$(uname -r) --diff

# Generate remediation script
python3 kernel_config_remediation.py --current /boot/config-$(uname -r) --remediate

# Check kexec availability
python3 kernel_config_remediation.py --check-kexec

# View kexec workflow guide
python3 kernel_config_remediation.py --kexec-guide

# Or use pf.py tasks:
./pf.py kernel-config-diff
./pf.py kernel-config-remediate
./pf.py kernel-kexec-check
```

### Firmware Checksum Database (`firmware_checksum_db.py`)

Manages database of known-good firmware checksums for bootkit detection and verification.

**Features:**
- SQLite database for firmware checksums (SHA256, SHA1, MD5)
- Add, verify, list, search firmware entries
- Export/import JSON for database sharing
- Confidence scoring system (0-100)
- Vendor, model, version metadata

**Quick Start:**
```bash
# List all firmware in database
python3 firmware_checksum_db.py --list

# Verify a firmware file
python3 firmware_checksum_db.py --verify /path/to/bios.bin

# Add firmware to database
python3 firmware_checksum_db.py --add /path/to/bios.bin \
  --vendor "ASUS" \
  --model "ROG X570-E" \
  --version "4021" \
  --confidence 90

# Export database to JSON
python3 firmware_checksum_db.py --export firmware_backup.json

# Import from JSON
python3 firmware_checksum_db.py --import firmware_backup.json

# Or use pf.py tasks:
./pf.py firmware-checksum-list
FIRMWARE_PATH=/path/to/bios.bin ./pf.py firmware-checksum-verify
```

## Existing Tools

### Module Signing (`pgmodsign.py`)

Sign kernel modules for Secure Boot compatibility.

**Quick Start:**
```bash
# Sign a single module
python3 pgmodsign.py /path/to/module.ko

# Sign all modules recursively
python3 pgmodsign.py /lib/modules/$(uname -r) --force

# Or use pf.py task:
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

## Integration with PhoenixBoot

All utilities are integrated into the PhoenixBoot task system via `core.pf`. Use `./pf.py list` to see all available tasks.

### Complete Security Workflow

```bash
# 1. Run comprehensive security check
sudo ./pf.py secure-env

# 2. Analyze kernel hardening
./pf.py kernel-hardening-report

# 3. Compare with baseline
./pf.py kernel-config-diff

# 4. Generate remediation
./pf.py kernel-config-remediate

# 5. Verify firmware (if available)
FIRMWARE_PATH=/sys/firmware/efi ./pf.py firmware-checksum-verify

# 6. Check results
sudo ./pf.py secure-env
```

## Documentation

- [Kernel Hardening Guide](../docs/KERNEL_HARDENING_GUIDE.md) - Comprehensive guide
- [Secure Environment Command](../docs/SECURE_ENV_COMMAND.md) - Security checks
- [Main README](../README.md) - Project overview

## Requirements

- Python 3.8+
- Root access (for some operations)
- Linux kernel with UEFI support

## Support

For issues or questions:
- GitHub Issues: https://github.com/P4X-ng/PhoenixBoot/issues
- Documentation: docs/
