# 🔥 PhoenixBoot - Secure Boot Defense System

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()

**PhoenixBoot** (also known as PhoenixGuard) is a production-ready firmware defense system designed to protect against bootkits, rootkits, and supply chain attacks. It provides hardware-level firmware recovery, secure boot enforcement, and a complete UEFI boot chain with cryptographic verification.

## 🎯 NEW: Turnkey SecureBoot Bootable Media Creator

**The simplest way to create SecureBoot-enabled boot media from any ISO!**

```bash
# One command creates everything you need:
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso

# Output: USB image ready to write, with keys enrolled and instructions included
# Write to USB: sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress
```

This new script solves the confusion around multiple runners and provides:
- ✅ Automatic SecureBoot key generation (PK, KEK, db)
- ✅ Bootable ESP with Microsoft-signed shim (works immediately!)
- ✅ Key enrollment tool included on the media
- ✅ Clear first-boot instructions for enrollment
- ✅ ISO loopback support (boots your ISO directly)
- ✅ Works on USB or CD/DVD

**See [SecureBoot Bootable Media Guide](docs/SECUREBOOT_BOOTABLE_MEDIA.md) for detailed instructions.**

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

**Status**: ✅ Ready to test
- ✅ Source files created: `staging/src/UUEFI.c`, `UUEFI.inf`
- ✅ Build script ready: `staging/tools/build-uuefi.sh`
- ✅ Binary built and different from NuclearBootEdk2.efi
- ✅ Test workflow available: `./pf.py workflow-test-uuefi`
- ℹ️  Requires QEMU and OVMF to run tests

**To test UUEFI**:
```bash
# Ensure ESP is built
./pf.py build-package-esp

# Run UUEFI test (requires QEMU)
./pf.py workflow-test-uuefi

# Or use the direct test script
./pf.py test-qemu-uuefi
```

See `docs/UUEFI_INVESTIGATION.md` for detailed analysis.

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

The project uses `pf.py` from [pf-runner](https://github.com/P4X-ng/pf-runner) - a powerful task runner with an intuitive DSL that reads task definitions from `.pf` files. The runner supports advanced features like conditional execution, loops, and file synchronization.

#### Available Task Files

- `build.pf` - Build tasks
- `test.pf` - Testing tasks
- `os.pf` - OS-level operations
- `validate.pf` - Validation and verification
- `secure.pf` - Security operations
- `iso.pf` - ISO creation
- `usb.pf` - USB preparation
- `workflows.pf` - **NEW**: Complex workflows for artifact creation and deployment
- `pipelines.pf` - CI/CD pipeline tasks

#### New Workflow Commands

```bash
# Create all artifacts for ESP and CD
./pf.py workflow-artifact-create

# Prepare bootable CD structure
./pf.py workflow-cd-prepare

# Generate comprehensive secure boot instructions
./pf.py workflow-secureboot-instructions

# Complete workflow: artifacts + CD + docs
./pf.py workflow-complete-esp-cd

# Verify all created artifacts
./pf.py workflow-verify-artifacts

# Test UUEFI in QEMU
./pf.py workflow-test-uuefi

# Write to USB (DESTRUCTIVE - set USB_DEVICE first)
USB_DEVICE=/dev/sdX ./pf.py workflow-usb-write
```

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
│   ├── artifacts/     # NEW: Complete artifact packages with docs
│   └── qemu/          # QEMU test logs and reports
├── 🔐 keys/            # Secure Boot keys (PK, KEK, db, MOK)
├── 📋 docs/            # Comprehensive documentation
├── 🧪 tests/           # Test suites
├── 🎭 examples_and_samples/  # Demonstration content
├── 💡 ideas/           # Future features and research
├── ⚙️ *.pf            # Task definitions for pf.py runner
├── 🐍 pf_parser.py     # NEW: pf-runner task execution engine
├── 📝 pf_grammar.py    # NEW: pf-runner grammar definitions
└── 🔗 pf.py           # NEW: Main pf runner entry point
```

## 🧪 Testing

### QEMU Testing

PhoenixBoot includes comprehensive end-to-end QEMU tests that boot real UEFI firmware (OVMF):

```bash
# Run main boot test
./pf.py test-qemu

# Run with Secure Boot enabled
./pf.py test-qemu-secure-positive

# Run Secure Boot strict mode test
./pf.py test-qemu-secure-strict

# Test NuclearBoot corruption detection (negative attestation)
./pf.py test-qemu-secure-negative-attest

# Test UUEFI diagnostic tool
./pf.py test-qemu-uuefi

# Test cloud-init integration with username/password
./pf.py test-qemu-cloudinit

# Run all end-to-end tests
./pf.py test-e2e-all
```

Test results are saved in:
- Serial logs: `out/qemu/serial*.log`
- JUnit reports: `out/qemu/report*.xml`

### Automated Testing (GitHub Actions)

All tests run automatically via GitHub Actions on every push and pull request:
- ✅ Basic QEMU boot
- ✅ SecureBoot with NuclearBoot
- ✅ SecureBoot strict mode
- ✅ Corruption detection (negative attestation)
- ✅ UUEFI diagnostic tool
- ✅ Cloud-Init integration

See `.github/workflows/e2e-tests.yml` for the complete workflow configuration.

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
- `docs/UUEFI_INVESTIGATION.md` - **NEW**: UUEFI crash investigation and resolution

**Artifact Creation Documentation**:
- Generated documentation in `out/artifacts/docs/`:
  - `SECURE_BOOT_SETUP.md` - Comprehensive secure boot setup guide
  - `README_CD.txt` - Quick start for CD/ISO users
  - `CHECKSUMS.txt` - Artifact verification checksums

Generate artifact documentation with:
```bash
./pf.py workflow-secureboot-instructions
```

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

### UUEFI Testing
**Status**: ✅ RESOLVED

**Previous Issue**: UUEFI.efi was identical to NuclearBootEdk2.efi, causing immediate crashes due to strict security checks.

**Current Status**: 
- ✅ UUEFI.efi is now a proper diagnostic tool (verified by MD5 checksum)
- ✅ Source code reviewed and contains correct implementation
- ✅ Build from EDK2 toolchain
- ✅ Workflow tasks available for testing: `./pf.py workflow-test-uuefi`

**Testing**: Requires QEMU environment. See `docs/UUEFI_INVESTIGATION.md` for detailed analysis.

**Note**: If you still experience issues, run `./pf.py workflow-test-uuefi` which includes diagnostics and log analysis.

## Alex notes

As the project currently stands, two of the things stand out here as very practical for everyday use and setup of a computer. First is, you can generate secure boot certs very easily (check the pf tasks, there's one to create a new set of keys and put them in EFI, from there you can easily enroll them). For me I use this everyday to spin up new machines with a write-only USB (hardware protected). Barring that I do recommend an actual CD burner that connects via USB, they're super cheap and the medium is immutable once burned, so burn it, check the image hash, and you know you're good to go. If you use PhoenixBoot's image burner you just point it at an ISO, it'll generate all necessary artifacts for secureboot, and you can enroll on first boot. It should also enroll the CD through a shimx64.efi or BOOTX64.efi. Though that's not strictly necessary (I skip that, because secure boot can be touchy with ISOs depending on the drivers you load at boot), but after initial install of the OS boot up to BIOS, enroll those custom keys, takes about 2 minutes, and you're well on your way. In other words, right now it's great as a convenience tool for new boots, or for changing keys on secure boot. 

So SecureBoot is nice but it's also kind of a pain in the ass. Specifically  kernel modules have to be signed, and there's a few fairly key ones that I use in ubuntu that come with no signature (lookin' at you apfs.ko). SecureBoot has a signing tool, it'll use you MOK.crt to sign it for your OS, and pop you into a screen to enter a password. Then reboot, at reboot the MOK manager should show up. Enter that password and you've got a PhoenixBoot signed kernel mod. 

Another useful feature right now is, if you don't have an immutable medium available, or even if you just don't feel like getting up and using a USB stick, it creates a new partition with an image burned into it in the ESP. That means you can boot from your boot partition as if there were a USB stick in there. Basically it's a fake little cd, a little trickery there. This can be used for two things (and they're two separate operations on PB) - first is new install of an OS, though again I do recommend an immutable medium, but it's also used as a recovery environment. Currently I'd use the KVM recovery env. KVM/QEMU are there in a minimal recovery environment that has flashrom and a handful of other tools to manage, analyze, and mess with your boot. If you're new to messing with boot stuff (I was when I started this project), a good first start is to totally wipe your BIOS and reinstall it. You can use flashrom from this recovery environment to do that. All of the permissions are set for it, so it shouldn't fail. 

The other modes and other stuff - they need a good amount of testing before they're ready for prime time. By all means feel free to test around and see some of the other utility scripts and workflows we implement - i've been pretty careful not to have anything that might hurt your computer. At worst you'll mess up your boot, which can be flashed again. That said every warning out there tells me there's a possibility of bricking your computer with these things. I've never experienced that, but it sounds like less than fun, so still be careful!




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
