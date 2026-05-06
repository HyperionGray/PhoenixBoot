# PhoenixBoot DoD Compliance Mode

## Overview

`phoenixboot-dod` is a Department of Defense (DoD) verified CLI for PhoenixBoot.  
It wraps the same underlying functionality as `phoenixboot` but adds:

- **DISA STIG compliance checks** before and after operations
- **Audit logging** of every operation with user and timestamp
- **FIPS 140-2/140-3 mode detection** with optional enforcement
- **DoD-specific commands** (`dod-check`, `dod-status`, `dod-audit-log`)
- **DISA STIG references** in help text and compliance reports

## Applicable Standards

| Standard | Description |
|----------|-------------|
| DISA STIG RHEL-08-010170 | Mandatory Access Control (SELinux) |
| DISA STIG RHEL-08-010370 | Kernel module signing / Secure Boot |
| DISA STIG RHEL-08-010372 | kexec control |
| DISA STIG RHEL-08-010430 | KASLR (kernel address randomization) |
| NIST SP 800-147 | BIOS Protection Guidelines |
| NIST SP 800-147B | BIOS Protection Guidelines for Servers |
| NIST SP 800-155 | BIOS Integrity Measurement |
| NIST SP 800-131A | Transitioning Cryptographic Algorithms and Key Lengths |
| FIPS 140-2 / 140-3 | Cryptographic Module Validation |

## Usage

```bash
# Show all available commands (includes DoD-specific commands)
./phoenixboot-dod help

# Show DoD/FIPS status of the current system
./phoenixboot-dod dod-status

# Run full DISA STIG compliance check
./phoenixboot-dod dod-check

# All standard phoenixboot commands work as-is:
./phoenixboot-dod setup
./phoenixboot-dod build
./phoenixboot-dod verify
./phoenixboot-dod status
./phoenixboot-dod secure keygen
./phoenixboot-dod secure check
./phoenixboot-dod secure media --iso /path/to/os.iso
```

## DoD-Specific Commands

### `dod-check`

Runs a comprehensive DISA STIG compliance pre-flight check:

```
╔══════════════════════════════════════════════════════════════════╗
║        PhoenixBoot DoD Compliance Check                         ║
║        DISA STIG / NIST SP 800-147 / FIPS 140-2                ║
╚══════════════════════════════════════════════════════════════════╝

  [ Cryptographic Compliance - FIPS 140-2/140-3 ]
  [PASS] FIPS-001  Kernel FIPS mode active
  [PASS] FIPS-002  OpenSSL FIPS provider available

  [ Secure Boot - DISA STIG RHEL-08-010370 ]
  [PASS] STIG-SB-001  UEFI system (Secure Boot capable)
  [PASS] STIG-SB-002  Secure Boot enabled
  ...
```

Checks performed:

| Check ID | Description | Reference |
|----------|-------------|-----------|
| FIPS-001 | Kernel FIPS mode active | FIPS 140-2/140-3 |
| FIPS-002 | OpenSSL FIPS provider available | FIPS 140-2/140-3 |
| STIG-SB-001 | UEFI system (Secure Boot capable) | DISA STIG RHEL-08-010370 |
| STIG-SB-002 | Secure Boot enabled | DISA STIG RHEL-08-010370 |
| STIG-KMS-001 | `CONFIG_MODULE_SIG_FORCE=y` | DISA STIG RHEL-08-010370 |
| STIG-KMS-002 | `CONFIG_MODULE_SIG=y` | DISA STIG RHEL-08-010370 |
| STIG-KX-001 | `CONFIG_KEXEC` disabled | DISA STIG RHEL-08-010372 |
| STIG-MAC-001 | SELinux/AppArmor in Enforcing mode | DISA STIG RHEL-08-010170 |
| STIG-KASLR-001 | `CONFIG_RANDOMIZE_BASE=y` (KASLR) | DISA STIG RHEL-08-010430 |
| DOD-KEY-001 | Private key file permissions (600/400) | NIST SP 800-147 |

### `dod-status`

Shows a quick summary of FIPS mode, Secure Boot status, and SELinux status.

### `dod-audit-log`

Displays the DoD audit log for the current session.  
All operations are recorded to `<PHOENIX_ROOT>/logs/dod-audit.log`.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOD_FIPS_REQUIRED` | `0` | Set to `1` to abort if kernel FIPS mode is not active |
| `DOD_AUDIT_LOG` | `<PHOENIX_ROOT>/logs/dod-audit.log` | Override audit log path |
| `DOD_MODE` | always `1` | Automatically exported; signals pf.py that DoD mode is active |

### FIPS Enforcement Example

```bash
# Require FIPS mode (aborts if kernel is not in FIPS mode)
DOD_FIPS_REQUIRED=1 ./phoenixboot-dod secure keygen
```

## Audit Logging

Every operation performed via `phoenixboot-dod` is logged:

```
[2026-01-15T14:30:00Z] [DOD-AUDIT] user=jdoe cmd=secure keygen -- DoD CLI invoked: phoenixboot-dod secure keygen
[2026-01-15T14:30:00Z] [DOD-AUDIT] user=jdoe cmd=secure keygen -- FIPS 140-2/140-3 mode: ACTIVE
[2026-01-15T14:30:00Z] [DOD-AUDIT] user=jdoe cmd=secure keygen -- Secure Boot status: SecureBoot enabled
```

Log entries include:
- UTC timestamp
- Authenticated username
- Command executed
- FIPS mode status
- Secure Boot status

## Cryptographic Algorithm Compliance

PhoenixBoot already generates NIST-approved cryptographic material:

| Material | Algorithm | Compliance |
|----------|-----------|------------|
| Secure Boot keys (PK/KEK/db) | RSA-4096, SHA-256 | ✓ FIPS 140-2, NIST SP 800-131A |
| Key Exchange signatures | RSA-4096, SHA-256 | ✓ FIPS 140-2, NIST SP 800-131A |
| Kernel module signatures | RSA + SHA-256 | ✓ FIPS 140-2 |

RSA-4096 exceeds the NIST SP 800-131A minimum of RSA-2048 (112 bits of security)
and satisfies the recommended RSA-3072 level.

## Relationship to Base `phoenixboot` CLI

`phoenixboot-dod` is a superset of `phoenixboot`:
- All standard `phoenixboot` commands work identically
- Additional DoD checks and audit logging wrap every operation
- The `DOD_MODE=1` environment variable is automatically exported to all
  underlying `pf.py` task invocations
- No functionality is removed or restricted compared to `phoenixboot`

The base `phoenixboot` CLI was not modified; changes that would have
required restricting user functionality were instead placed only in
`phoenixboot-dod`.

## References

- [DISA STIG for RHEL 8](https://www.stigviewer.com/stig/red_hat_enterprise_linux_8/)
- [NIST SP 800-147 BIOS Protection Guidelines](https://doi.org/10.6028/NIST.SP.800-147)
- [NIST SP 800-131A Cryptographic Algorithm Transitions](https://doi.org/10.6028/NIST.SP.800-131Ar2)
- [FIPS 140-2 / 140-3 Cryptographic Module Standards](https://csrc.nist.gov/publications/fips)
- [Linux Kernel Self Protection Project](https://kernsec.org/wiki/index.php/Kernel_Self_Protection_Project)
