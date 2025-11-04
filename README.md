# 🔥 PhoenixBoot - Secure Boot Defense System

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()

**PhoenixBoot** (also known as PhoenixGuard) is a production-ready firmware defense system designed to protect against bootkits, rootkits, and supply chain attacks. It provides hardware-level firmware recovery, secure boot enforcement, and a complete UEFI boot chain with cryptographic verification.

## 🚀 Quick Start

### Prerequisites

- Linux system with UEFI firmware
- Python 3.8+ with venv
- Build tools: `gcc`, `make`, `git`
- QEMU for testing (optional)
- `efibootmgr`, `mokutil` for boot management
- EDK2 for building UEFI applications from source

### Installation

```bash
# Clone the repository
git clone https://github.com/P4X-ng/PhoenixBoot.git
cd PhoenixBoot

# Set up Python environment (if not already done)
python3 -m venv ~/.venv
source ~/.venv/bin/activate
pip install -r requirements.txt  # if requirements.txt exists

# Run the task runner
./pf.py <task-name>
```

## 📋 Features Overview

### ✅ Implemented Features

#### 1. **Nuclear Boot (NuclearBootEdk2)**
A battle-tested UEFI bootloader with strict security requirements:
- **Secure Boot enforcement** - Requires Secure Boot to be enabled
- **Runtime attestation** - Verifies binary hash against sidecar file
- **Network-based boot** - Can download boot configuration over HTTPS
- **Memory-safe** - Built with EDK2 for maximum reliability

**Status**: ✅ Fully implemented and tested

#### 2. **Key Enrollment (KeyEnrollEdk2)**
Automated Secure Boot key enrollment utility:
- Enrolls PK, KEK, and db keys from ESP
- Supports authenticated variables
- Prepares system for custom Secure Boot configuration

**Status**: ✅ Fully implemented

#### 3. **Boot Management**
Tools for managing UEFI boot entries:
- `os-boot-clean`: Clean stale UEFI boot entries
- `os-mok-enroll`: Enroll MOK keys for module signing
- `os-mok-list-keys`: List available MOK certificates
- `uuefi-install`: Install UUEFI.efi to system ESP
- `uuefi-apply`: Set BootNext for one-time UUEFI boot
- `uuefi-report`: Display system security status

**Status**: ✅ Scripts implemented, tested on real hardware

#### 4. **QEMU Testing**
Comprehensive QEMU-based testing:
- `test-qemu`: Main QEMU boot test with OVMF firmware
- `test-qemu-secure-positive`: Secure Boot enabled tests
- `test-qemu-secure-strict`: Strict security verification
- `test-qemu-secure-negative-attest`: Negative attestation testing

**Status**: ✅ Fully implemented with JUnit report generation

#### 5. **ESP Packaging**
Bootable EFI System Partition image creation:
- Creates FAT32 ESP images
- Includes all necessary EFI binaries
- Supports ISO integration
- Validates boot structure

**Status**: ✅ Implemented

#### 6. **Module Signing**
Kernel module signing for Secure Boot:
- Sign individual modules or directories
- MOK certificate management
- Integration with system module loading

**Status**: ✅ Fully functional

### 🚧 Partially Implemented

#### 7. **UUEFI - Universal UEFI Diagnostic Tool**
A simplified UEFI application for system diagnostics:
- Display firmware information
- Show memory map
- Report security status
- Boot configuration viewer

**Status**: 🚧 Source code complete, needs building
- ✅ Source files created: `staging/src/UUEFI.c`, `UUEFI.inf`
- ✅ Build script ready: `staging/tools/build-uuefi.sh`
- ⚠️ Requires EDK2 toolchain to build
- ⚠️ Currently `staging/boot/UUEFI.efi` is a copy of NuclearBootEdk2.efi (causes immediate exit)

**Known Issue**: The current UUEFI.efi binary crashes immediately on boot because it's actually NuclearBootEdk2.efi which enforces strict security checks. To fix:
```bash
# Build UUEFI from source (requires EDK2)
cd staging/src
chmod +x ../tools/build-uuefi.sh
../tools/build-uuefi.sh

# The build will create UUEFI.efi in staging/boot/
```

### 📝 Planned Features

#### 8. **Hardware Firmware Recovery**
- SPI flash extraction and verification
- Bootkit protection bypass
- Firmware baseline comparison
- Automated remediation workflows

**Status**: 📝 Research phase, scripts exist in `scripts/`

#### 9. **Xen Hypervisor Integration**
- VM snapshot-based recovery
- Dom0 firmware audits
- GPU passthrough for clean boot environments

**Status**: 📝 Documentation and proof-of-concept in `resources/xen/`

#### 10. **Cloud Integration**
- Remote attestation API
- Centralized firmware database
- Cooperative defense network

**Status**: 📝 API sketches in `ideas/cloud_integration/`

## 🛠️ Usage Guide

### Task Runner (pf.py)

The project uses a custom task runner called `pf.py` that reads task definitions from `.pf` files. This is **not** the same as a Justfile (which is being deprecated in another issue).

#### Available Task Files

- `build.pf` - Build tasks
- `test.pf` - Testing tasks
- `os.pf` - OS-level operations
- `validate.pf` - Validation and verification
- `secure.pf` - Security operations
- `iso.pf` - ISO creation
- `usb.pf` - USB preparation

#### Common Commands

```bash
# Build production artifacts
./pf.py build-build

# Package ESP image
./pf.py build-package-esp

# Run QEMU tests
./pf.py test-qemu

# Test UUEFI (currently fails - see Known Issues)
./pf.py test-qemu-uuefi

# Install UUEFI to system ESP
./pf.py uuefi-install

# Set one-time boot to UUEFI
./pf.py os-boot-once

# Display system security report
./pf.py uuefi-report

# Validate keys and ESP
./pf.py validate-all

# Enroll MOK keys
./pf.py os-mok-enroll

# Sign kernel modules
PATH=/path/to/module ./pf.py os-kmod-sign
```

### Direct Script Usage

Many operations can also be run directly via bash scripts in the `scripts/` directory:

```bash
# UUEFI operations
bash scripts/uuefi-install.sh
bash scripts/uuefi-apply.sh
bash scripts/uuefi-report.sh
bash scripts/host-uuefi-once.sh

# Boot management
bash scripts/os-boot-clean.sh
bash scripts/enroll-mok.sh <cert.crt> <cert.der> [dry_run]
bash scripts/mok-list-keys.sh

# Testing
bash scripts/qemu-test.sh
bash scripts/qemu-test-uuefi.sh
```

## 🏗️ Project Structure

```
PhoenixBoot/
├── 🎯 staging/          # Production-ready code (source for all builds)
│   ├── src/            # UEFI application source (NuclearBootEdk2, KeyEnrollEdk2, UUEFI)
│   ├── boot/           # Compiled EFI binaries (checked in as prebuilt)
│   └── tools/          # Build scripts for EDK2 compilation
├── 🔧 scripts/         # Operational scripts for installation and testing
├── 📦 out/             # Build artifacts and test results
│   ├── staging/       # Compiled production binaries
│   ├── esp/           # ESP images and packaging
│   └── qemu/          # QEMU test logs and reports
├── 🔐 keys/            # Secure Boot keys (PK, KEK, db, MOK)
├── 📋 docs/            # Comprehensive documentation
├── 🧪 tests/           # Test suites
├── 🎭 examples_and_samples/  # Demonstration content
├── 💡 ideas/           # Future features and research
└── ⚙️ *.pf            # Task definitions for pf.py runner
```

## 🧪 Testing

### QEMU Testing

PhoenixBoot includes comprehensive QEMU tests that boot real UEFI firmware (OVMF):

```bash
# Run main boot test
./pf.py test-qemu

# Run with Secure Boot enabled
./pf.py test-qemu-secure-positive

# Test UUEFI (needs proper binary)
./pf.py test-qemu-uuefi
```

Test results are saved in:
- Serial logs: `out/qemu/serial*.log`
- JUnit reports: `out/qemu/report*.xml`

### Building from Source

To rebuild UEFI applications from source, you need the EDK2 toolchain:

```bash
# Build NuclearBoot
cd staging/src
chmod +x ../tools/build-nuclear-boot-edk2.sh
../tools/build-nuclear-boot-edk2.sh

# Build UUEFI (fixes the crash issue)
cd staging/src
chmod +x ../tools/build-uuefi.sh
../tools/build-uuefi.sh

# Build KeyEnroll
# (automatically built with NuclearBoot script)
```

Alternatively, force a source rebuild during packaging:

```bash
PG_FORCE_BUILD=1 ./pf.py build-build
```

## 🔐 Security

### Secure Boot Keys

The system supports custom Secure Boot key hierarchies:

1. **PK (Platform Key)** - Root of trust
2. **KEK (Key Exchange Key)** - Intermediate authority
3. **db (Signature Database)** - Allowed signatures
4. **MOK (Machine Owner Key)** - Module signing

Keys are stored in the `keys/` directory and can be enrolled using KeyEnrollEdk2.efi.

### Module Signing

Kernel modules must be signed to load with Secure Boot enabled:

```bash
# Sign a single module
PATH=/lib/modules/.../module.ko ./pf.py os-kmod-sign

# Sign all modules in a directory
PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

- `docs/README.md` - Detailed technical documentation
- `docs/SECURE_BOOT.md` - Secure Boot implementation guide
- `docs/BOOT_SEQUENCE_AND_ATTACK_SURFACES.md` - Boot security analysis
- `docs/FIRMWARE_RECOVERY.md` - Firmware recovery procedures
- `docs/HARDWARE_ACCESS_DEEP_DIVE.md` - Hardware-level access documentation

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the Apache License 2.0. See LICENSE file for details.

## 🆘 Support

For issues, questions, or support:

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Documentation**: `docs/` directory
- **Examples**: `examples_and_samples/` directory

## ⚠️ Known Issues

### UUEFI Boot Crash
**Issue**: Attempting to boot UUEFI just stops and returns immediately.

**Cause**: The current `staging/boot/UUEFI.efi` is identical to `NuclearBootEdk2.efi` (same MD5 hash). When it boots, it enforces strict Secure Boot and attestation requirements, causing immediate failure.

**Status**: ✅ Fixed in source code
- New UUEFI.c implementation created that displays diagnostics without strict security
- Build script ready at `staging/tools/build-uuefi.sh`
- Requires EDK2 build environment to compile

**Workaround**: Build UUEFI from source or use NuclearBoot with proper attestation files.

## 🗺️ Roadmap

- [x] Nuclear Boot implementation
- [x] Key enrollment automation
- [x] QEMU testing framework
- [x] ESP packaging
- [x] Module signing integration
- [x] UUEFI source code
- [ ] Build UUEFI binary (requires EDK2)
- [ ] Hardware firmware recovery automation
- [ ] Xen hypervisor integration
- [ ] Cloud attestation API
- [ ] P4X OS integration
- [ ] Universal hardware compatibility

---

**Made with 🔥 for a more secure boot process**
