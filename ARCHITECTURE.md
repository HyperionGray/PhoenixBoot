# 🏗️ PhoenixBoot Architecture

## Overview

PhoenixBoot (PhoenixGuard) is a firmware defense system that provides hardware-level recovery, secure boot enforcement, and comprehensive UEFI boot chain protection. This document describes the system architecture and design principles.

## Core Design Principles

### 1. Defense in Depth
PhoenixBoot operates on multiple security layers:
- **Hardware Layer**: Direct hardware register access below the bootkit layer
- **Firmware Layer**: UEFI applications with cryptographic verification
- **Boot Chain Layer**: Secure Boot key management and enforcement
- **OS Layer**: Kernel module signing and security checks

### 2. Assume Breach Philosophy
PhoenixBoot assumes attacks **will** succeed and focuses on:
- **Guaranteed recovery** from firmware-level compromises
- **Multiple independent recovery paths** for resilience
- **Hardware-level operations** that bypass software-based attacks
- **Cryptographic verification** at every boot stage

### 3. Modular Architecture
All components are isolated and independently testable:
- **Container-based** for reproducibility
- **Script-based** for transparency and auditability
- **Task-based** for workflow automation

## System Components

### 1. UEFI Applications (staging/src/)

#### NuclearBootEdk2.efi
Battle-tested UEFI bootloader with strict security:
- **Secure Boot enforcement** - Requires Secure Boot enabled
- **Runtime attestation** - Verifies binary hash against sidecar file
- **Network boot support** - Downloads configuration over HTTPS
- **Memory-safe** - Built with EDK2 for reliability

#### KeyEnrollEdk2.efi
Automated Secure Boot key enrollment:
- Enrolls PK, KEK, and db keys from ESP
- Supports authenticated variables
- Prepares system for custom Secure Boot configuration

#### UUEFI.efi (v3.1)
Universal UEFI diagnostic and management tool:
- **System information** - Firmware version, memory, security status
- **Variable management** - View, edit, and analyze all UEFI variables
- **Security analysis** - Detect suspicious variables and patterns
- **Nuclear wipe capability** - Complete system sanitization
- **Debug diagnostics** - Comprehensive system dump for deep analysis

### 2. Task Runner (pf.py)

Central automation system using the pf-runner framework:
- **core.pf** - Essential functionality (build, test, keys, MOK)
- **secure.pf** - Advanced Secure Boot operations
- **workflows.pf** - Multi-step workflows (ESP, CD, USB)
- **maint.pf** - Maintenance tasks (lint, format, cleanup)

### 3. Script Organization (scripts/)

All operational scripts organized by category:

```
scripts/
├── build/              # Build operations
├── testing/            # QEMU and validation tests
├── mok-management/     # MOK and module signing
├── esp-packaging/      # ESP image creation
├── secure-boot/        # SecureBoot key management
├── validation/         # Security checks and scanning
├── recovery/           # Hardware recovery and wipe
├── uefi-tools/         # UUEFI operations
├── usb-tools/          # USB media creation
├── qemu/               # QEMU test runners
└── maintenance/        # Project maintenance
```

### 4. Python Utilities (utils/)

Specialized Python tools for complex operations:
- **pgmodsign.py** - Kernel module signing
- **kernel_hardening_analyzer.py** - DISA STIG compliance checking
- **kernel_config_remediation.py** - Kernel config fixing
- **firmware_checksum_db.py** - Firmware verification
- **cert_inventory.py** - Certificate management
- **uefi_variable_analyzer.py** - UEFI variable analysis

### 5. Container Architecture (containers/)

Modular, reproducible container-based execution:

#### Build Container
- EDK2 toolchain for UEFI compilation
- GCC, Make, NASM for native builds
- Produces: NuclearBootEdk2.efi, KeyEnrollEdk2.efi, UUEFI.efi

#### Test Container
- QEMU for UEFI boot testing
- OVMF firmware for SecureBoot testing
- JUnit report generation
- Negative attestation testing

#### Installer Container
- ESP image creation (FAT32)
- ISO integration and loopback
- Bootable media packaging
- Key enrollment preparation

#### Runtime Container
- On-host operations (efibootmgr, mokutil)
- Real hardware UEFI variable access
- Boot entry management
- MOK enrollment

#### TUI Container
- Interactive terminal interface
- Task categorization and execution
- Real-time output display
- Modern, user-friendly experience

## Data Flow Architecture

### Build Workflow

```
Source Code (staging/src/)
    ↓
Build Container (EDK2 compilation)
    ↓
Production Binaries (staging/boot/)
    ↓
ESP Packaging (out/esp/)
    ↓
Bootable Media (USB/CD/ISO)
```

### Security Validation Workflow

```
System Boot
    ↓
secure-env-check.sh
    ├─► EFI Variable Scan
    ├─► Boot Integrity Check
    ├─► Secure Boot Status
    ├─► Kernel Security Check
    ├─► Bootkit Detection
    └─► Module Signature Verification
    ↓
Security Report (JSON + Text)
```

### Recovery Workflow

```
Compromised Firmware Detected
    ↓
Hardware Recovery Script
    ├─► Direct Register Access (/dev/mem)
    ├─► Unlock Flash Protection (FLOCKDN)
    ├─► Dump Current Firmware (flashrom)
    ├─► Verify Against Baseline
    └─► Restore Known-Good Firmware
    ↓
System Restored
```

## Key Hierarchies

### Secure Boot Keys
```
PK (Platform Key) - Root of trust
    ↓
KEK (Key Exchange Key) - Intermediate authority
    ↓
db (Signature Database) - Allowed signatures
    ↓
Signed Bootloaders & Kernels
```

### Module Signing Keys
```
MOK (Machine Owner Key) - User-controlled
    ↓
Signed Kernel Modules
    ↓
Module Loading with SecureBoot Enabled
```

## Hardware Access Layers

PhoenixBoot operates at multiple hardware levels:

### Layer 1: Software Abstraction (Where Bootkits Operate)
- UEFI Runtime Services
- Operating System APIs
- File System Access

### Layer 2: Hardware Registers (PhoenixGuard's Domain)
- Direct Memory-Mapped I/O (/dev/mem)
- SPI Controller Registers
- CPU Model Specific Registers (MSRs)
- Chipset Configuration Registers

**Key Innovation**: PhoenixGuard operates **below** the software layer where bootkits live, making it immune to firmware-level malware.

## Directory Structure

```
PhoenixBoot/
├── pf.py, *.pf              # Task runner and definitions
├── staging/                 # Production-ready code
│   ├── src/                # UEFI application source
│   ├── boot/               # Compiled EFI binaries
│   └── tools/              # Build scripts
├── scripts/                # Operational scripts (organized)
├── utils/                  # Python utilities
├── containers/             # Container definitions
├── out/                    # Build artifacts and results
│   ├── staging/           # Compiled binaries
│   ├── esp/               # ESP images
│   ├── qemu/              # Test logs and reports
│   └── keys/              # Generated keys
├── keys/                   # SecureBoot keys (legacy)
├── docs/                   # Comprehensive documentation
├── tests/                  # Test suites
└── examples_and_samples/  # Demo materials
```

## Testing Strategy

### 1. Unit Testing
- Individual script validation
- Python utility tests
- UEFI application compilation tests

### 2. Integration Testing
- QEMU boot tests (basic, SecureBoot, strict mode)
- Negative attestation testing (corruption detection)
- UUEFI diagnostic testing
- End-to-end workflows

### 3. Hardware Testing
- Real hardware boot validation
- Key enrollment on physical systems
- Module signing verification
- Recovery procedure validation

## Security Architecture

### Threat Model

**Protected Against:**
- ✅ Bootkits (firmware-level malware)
- ✅ Rootkits (kernel-level malware)
- ✅ Supply chain attacks (compromised firmware)
- ✅ Unauthorized boot modifications
- ✅ Malicious kernel modules

**Not Protected Against:**
- ⚠️ Hardware tampering (requires physical security)
- ⚠️ Side-channel attacks (timing, power analysis)
- ⚠️ Zero-day vulnerabilities in EDK2/firmware
- ⚠️ Evil maid attacks without boot password

### Defense Mechanisms

1. **Secure Boot Enforcement** - Cryptographic chain of trust
2. **Hardware-Level Recovery** - Direct register access
3. **Attestation** - Runtime binary verification
4. **Module Signing** - Prevent unsigned kernel modules
5. **Security Monitoring** - Continuous integrity checking
6. **Nuclear Wipe** - Complete system sanitization option

## Deployment Models

### 1. Development Environment
```bash
# Local development with containers
docker-compose --profile build up
docker-compose --profile test up
```

### 2. CI/CD Pipeline
```bash
# GitHub Actions automated testing
./pf.py build-build
./pf.py test-qemu
./pf.py test-e2e-all
```

### 3. Production System
```bash
# Systemd services with Podman Quadlet
systemctl start phoenixboot-runtime.service
```

### 4. Bootable Media
```bash
# Create standalone bootable media
./create-secureboot-bootable-media.sh --iso ubuntu.iso
```

## Extension Points

PhoenixBoot is designed to be extended:

### Adding New Tasks
1. Create script in appropriate `scripts/` subdirectory
2. Add task definition to relevant `.pf` file
3. Test with `./pf.py <task-name>`

### Adding New UEFI Applications
1. Add source to `staging/src/`
2. Create build script in `staging/tools/`
3. Update ESP packaging scripts

### Adding New Security Checks
1. Add check script to `scripts/validation/`
2. Integrate into `secure-env-check.sh`
3. Update reporting format

## Performance Considerations

- **Build Time**: EDK2 compilation ~2-5 minutes
- **Test Time**: QEMU boot tests ~30-60 seconds each
- **ESP Creation**: ~10-30 seconds
- **Security Scan**: ~5-15 seconds

## Best Practices

1. **Always test in QEMU first** before hardware deployment
2. **Use the task runner** (`./pf.py`) for consistent operations
3. **Keep keys secure** - Store in encrypted locations
4. **Regular security scans** - Run `secure-env` periodically
5. **Maintain baselines** - Keep known-good firmware checksums
6. **Document changes** - Track key enrollments and modifications

## Future Architecture Enhancements

- [ ] Cloud attestation API for remote verification
- [ ] Distributed firmware database for cooperative defense
- [ ] Hardware Security Module (HSM) integration
- [ ] Automated firmware update verification
- [ ] TPM 2.0 measured boot integration
- [ ] UEFI Capsule update support

---

**Made with 🔥 for a more secure boot process**
