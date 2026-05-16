# PhoenixBoot - Secure Boot Defense System

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Status](https://img.shields.io/badge/release-v0.1.0--alpha-orange)](ALPHA_RELEASE_PLAN.md)

> **Alpha status.** We are working toward the first OSS alpha tag,
> `v0.1.0-alpha`. The supported surface for the alpha is documented in
> [ALPHA_RELEASE_PLAN.md](ALPHA_RELEASE_PLAN.md). Anything under
> [`experimental/`](experimental/README.md) is explicitly **not** part of
> the alpha API: no CI, no compatibility promise, may be rewritten or
> removed without notice.

**PhoenixBoot** (also known as PhoenixGuard) is a firmware defense system designed to protect against bootkits, rootkits, and supply chain attacks. It provides Secure Boot key management, MOK-based kernel-module signing, attestation-enforced UEFI bootloaders, ESP packaging, QEMU-based end-to-end tests, and turnkey Secure-Boot-ready bootable media creation from any installer ISO.

## New to PhoenixBoot?

**[Start Here: Complete Bootkit Defense Workflow](docs/BOOTKIT_DEFENSE_WORKFLOW.md)**

This comprehensive guide walks you through **stopping bootkits completely** in three stages:
1. **Enable SecureBoot from the start** - Create install media with custom keys
2. **Clean OS installation** - Install with SecureBoot enforced
3. **Post-install protection** - Clear malicious EFI vars with the recovery tooling

**Result:** 99% of bootkits neutralized. The remaining 1% require hardware intervention (which we also support).

**Also available:**
- **[Getting Started Guide](docs/GETTING_STARTED.md)** - Quick introduction for new users
- **[SecureBoot Quick Reference](docs/SECUREBOOT_QUICKSTART.md)** - One-page command reference

## Quick Start: Three Ways to Begin

### 1. Interactive Setup Wizard (Easiest!)

**NEW:** Guided wizard walks you through the complete bootkit defense workflow:

```bash
./phoenixboot-wizard.sh
```

**What you get:**
- Step-by-step guidance through all three stages
- Create SecureBoot bootable media (Stage 1)
- Instructions for clean OS install (Stage 2)
- Progressive recovery for post-install cleanup (Stage 3)
- Built-in security checks
- Advanced options menu

### 2. One-Command Bootable Media Creation

**Create SecureBoot-enabled boot media from any ISO:**

```bash
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso

# Output: USB image ready to write, with keys enrolled and instructions included
# Write to USB: sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M status=progress
```

**Features:**
- Automatic SecureBoot key generation (PK, KEK, db)
- Bootable ESP with Microsoft-signed shim (works immediately!)
- Key enrollment tool included on the media
- Clear first-boot instructions for enrollment
- ISO loopback support (boots your ISO directly)
- Works on USB or CD/DVD

### 3. Interactive TUI

**Terminal User Interface for task management:**

```bash
./phoenixboot-tui.sh
```

**See [TUI Guide](docs/TUI_GUIDE.md) and [SecureBoot Bootable Media Guide](docs/SECUREBOOT_BOOTABLE_MEDIA.md) for detailed instructions.**

## Container Architecture & TUI Interface

PhoenixBoot now features a **modular container-based architecture** with an **interactive TUI**!

### Container-Based Architecture

All components now run in isolated, reproducible containers:

```bash
# Build artifacts
docker-compose --profile build up

# Run tests
docker-compose --profile test up

# Launch interactive TUI
docker-compose --profile tui up
```

**Benefits**:
- **Isolated environments** - Each component in its own container
- **Reproducible builds** - Consistent across all systems
- **Easy deployment** - Podman quadlet integration for systemd
- **Clear organization** - Build, test, installer, runtime, and TUI containers

**See [Container Architecture Guide](docs/CONTAINER_ARCHITECTURE.md) for detailed information.**

### Terminal User Interface (TUI)

Launch the interactive TUI for a modern, user-friendly experience:

```bash
# Direct launch
./phoenixboot-tui.sh

# Or via container
docker-compose --profile tui up
```

**Features**:
- **Organized task categories** - Tasks grouped by functionality
- **One-click execution** - Run tasks with a button press
- **Real-time output** - See task output as it happens
- **Modern design** - Clean, intuitive interface
- ⌨ **Keyboard navigation** - Full keyboard support

**See [TUI Guide](docs/TUI_GUIDE.md) for usage instructions.**

## Quick Start

> **New for users:** PhoenixBoot now includes comprehensive educational output!
> - Every key generation command explains what it creates and how to use it
> - README files in `keys/` and `out/keys/mok/` explain key hierarchies
> - New user guide: `docs/UNDERSTANDING_BOOT_ARTIFACTS.md` explains shims, keys, and boot concepts
> - **Never been confused about "which shim to use"? Start here!**

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
pip install -r requirements.txt # if requirements.txt exists

# Install the vendored pf-runner (pinned, ships with the repo)
pip install -e ./pf-runner

# Run a task
./pf list
./pf <task-name>
```

## Features Overview

### Implemented Features

#### 0. **Kernel Hardening and UEFI Variable Checks**
Comprehensive kernel configuration analysis and UEFI security verification:
- **Kernel Hardening Analyzer** - Check kernel config against DISA STIG standards
- **UEFI Variable Security** - Verify SecureBoot variables and firmware integrity
- **Firmware Checksum Database** - Validate firmware against known-good checksums
- **Kernel Config Remediation** - Fix kernel configs with kexec double-jump technique
- **DISA STIG Compliance** - Automated checks for security best practices
- **Configuration Diff** - Compare current kernel config against hardened baseline
- **Secure Boot Enablement Framework** - Double kexec method framework (educational)
- **Kernel Configuration Profiles** - Pre-configured profiles (permissive/hardened/balanced)

> **Note**: The Secure Boot enablement feature provides a framework and workflow demonstration.
> Hardware-specific enablement code is not included. Most users should enable Secure Boot
> through BIOS/UEFI setup (traditional method).

**Usage**: 
```bash
# Comprehensive security check
./pf.py secure-env

# Kernel hardening analysis
./pf.py kernel-hardening-check
./pf.py kernel-hardening-report

# Generate hardened baseline
./pf.py kernel-hardening-baseline

# Compare and remediate
./pf.py kernel-config-diff
./pf.py kernel-config-remediate

# Check kexec for remediation
./pf.py kernel-kexec-check

# Secure Boot enablement (NEW!)
./pf.py secureboot-check
sudo ./pf.py secureboot-enable-kexec

# Kernel config profiles (NEW!)
./pf.py kernel-profile-list
./pf.py kernel-profile-permissive
./pf.py kernel-profile-hardened
./pf.py kernel-profile-balanced
PROFILE=hardened ./pf.py kernel-profile-compare

# Firmware checksum management
./pf.py firmware-checksum-list
FIRMWARE_PATH=/path/to/bios.bin ./pf.py firmware-checksum-verify
```

**Documentation**: 
- See [Kernel Hardening Guide](docs/KERNEL_HARDENING_GUIDE.md)
- See [Secure Boot Enablement via Kexec](docs/SECUREBOOT_ENABLEMENT_KEXEC.md)

**Status**: Experimental/dev user workflow; internal boot app exists but still needs release hardening

#### 1. **Recovery Boot Path**
Internal recovery boot application with strict security requirements:
- **Secure Boot enforcement** - Requires Secure Boot to be enabled
- **Runtime attestation** - Verifies binary hash against sidecar file
- **Network-based boot** - Can download boot configuration over HTTPS
- **Memory-safe** - Built with EDK2 for maximum reliability

**Status**: Experimental/dev user workflow; internal boot app exists but still needs release hardening

#### 2. **Key Enrollment (KeyEnrollEdk2)**
Automated Secure Boot key enrollment utility:
- Enrolls PK, KEK, and db keys from ESP
- Supports authenticated variables
- Prepares system for custom Secure Boot configuration

**Status**: Fully implemented

#### 3. **Boot Management**
Tools for managing UEFI boot entries:
- `os-boot-clean`: Clean stale UEFI boot entries
- `os-mok-enroll`: Enroll MOK keys for module signing
- `os-mok-list-keys`: List available MOK certificates
- `uuefi-install`: Install UUEFI.efi to system ESP
- `uuefi-apply`: Set BootNext for one-time UUEFI boot
- `uuefi-report`: Display system security status

**Status**: Scripts implemented, tested on real hardware

#### 4. **QEMU Testing**
Comprehensive QEMU-based testing:
- `test-qemu`: Main QEMU boot test with OVMF firmware
- `test-qemu-secure-positive`: Secure Boot enabled tests
- `test-qemu-secure-strict`: Strict security verification
- `test-qemu-secure-negative-attest`: Negative attestation testing

**Status**: Fully implemented with JUnit report generation

#### 5. **ESP Packaging**
Bootable EFI System Partition image creation:
- Creates FAT32 ESP images
- Includes all necessary EFI binaries
- Supports ISO integration
- Validates boot structure

**Status**: Implemented

#### 6. **Module Signing**
Kernel module signing for Secure Boot:
- Sign individual modules or directories
- MOK certificate management
- Integration with system module loading

**Status**: Fully functional

#### 7. **Security Environment Check (`secure_env`)**
Comprehensive security validation and boot integrity checker:
- **EFI Variables Security** - Scans for suspicious modifications in EFI vars
- **Boot Integrity** - Verifies bootloader, kernel, and initramfs integrity
- **Secure Boot Status** - Validates Secure Boot configuration and enrollment
- **Kernel Security** - Checks kernel hardening features (lockdown, KASLR, etc.)
- **Bootkit Detection** - Scans for firmware-level malware against baseline
- **Module Signatures** - Verifies kernel modules are properly signed
- **Attack Vector Analysis** - Detects dangerous boot parameters and rootkit indicators
- **Automated Reporting** - Generates detailed text and JSON security reports

**Usage**: `./pf.py secure-env` or `bash scripts/secure-env-check.sh`

**Documentation**: See [docs/SECURE_ENV_COMMAND.md](docs/SECURE_ENV_COMMAND.md)

**Status**: Fully implemented and tested

### Partially Implemented

#### 8. **UUEFI - Universal UEFI Diagnostic Tool** Enhanced v3.1
A powerful UEFI application for system diagnostics and complete firmware-level configuration:
- **Display firmware information** - Vendor, version, UEFI revision
- **Show memory map** - Total and available memory
- **Report security status** - Secure Boot, Setup Mode, key enrollment
- **Boot configuration viewer** - BootOrder and boot entries
- **Complete EFI variable enumeration** - Read ALL variables with descriptions
- **Variable editing system** - Safely modify tweakable variables
- **Smart categorization** - Automatically group by type (boot, security, vendor)
- **Security heuristics engine** - Detect suspicious variables and patterns
- **Interactive menu system** - User-friendly navigation and management
- **Security analysis report** - Comprehensive findings with severity levels
- **ESP configuration viewer** - View config files from EFI System Partition
- **Reset workflow** - Complete system wipe guidance for malware response
- **Variable descriptions** - Human-readable explanations for every variable
- **v3.0: Comprehensive descriptions** - 150+ variable patterns documented (ASUS, Intel, WiFi, BT, etc.)
- **v3.0: Edit indicators** - Visual markers show which variables are safe to edit
- **v3.0: Reset menu** - Complete system sanitization suite with 4 options:
 - Vendor variable wipe (remove bloatware)
 - Full NVRAM reset (factory defaults, preserves security keys)
 - Disk wiping guide (nwipe instructions and workflow)
 - Complete nuclear wipe (NVRAM + disk for extreme malware situations)
- ** v3.1: Debug Diagnostics Mode** - EVERYTHING dump for deep analysis:
 - Complete variable data dump (hex + ASCII) for ALL variables
 - Protocol database enumeration (find hidden IOCTLs)
 - Configuration tables (ACPI, SMBIOS, etc.)
 - Detailed memory map with all regions
 - Full system dump (all of the above)

**Status**: Enhanced v3.1 and ready to use
- Source files: `staging/src/UUEFI.c`, `UUEFI.inf` (EDK2 build)
- GNU-EFI version: `staging/src/UUEFI-gnuefi.c` (alternative build)
- Build script: `staging/tools/build-uuefi.sh`
- Version 3.1.0 with debug everything mode
- Test workflow: `./pf.py workflow-test-uuefi`
- Companion scripts: `scripts/esp-config-extract.sh`, `scripts/nuclear-wipe.sh`
- ℹ Requires QEMU and OVMF to run tests

**To test UUEFI**:
```bash
# Ensure ESP is built
./pf.py build-package-esp

# Run UUEFI test (requires QEMU)
./pf.py workflow-test-uuefi

# Or use the direct test script
./pf.py test-qemu-uuefi
```

**Documentation**: 
- `docs/UUEFI_DEBUG_MODE.md` - v3.1 debug diagnostics complete guide
- `docs/UUEFI_V3_FEATURES.md` - v3.0 comprehensive feature guide
- `docs/UUEFI_ENHANCED.md` - v2.0 feature documentation
- `docs/UUEFI_INVESTIGATION.md` - Development history and troubleshooting

**Key Features for firmware recovery scenarios**:
- **Variable Descriptions**: Understand every firmware setting
- **Safe Editing**: Disable bloatware and telemetry
- **Security Analysis**: Detect firmware tampering
- **Full reset workflow**: Complete system reset guidance for serious malware
 - Remove all vendor bloat
 - Reset BIOS to factory defaults
 - Guide for secure disk wiping with nwipe
 - Full workflow for firmware-level malware removal

### Planned Features

#### 9. **Hardware Firmware Recovery**
- SPI flash extraction and verification
- Bootkit protection bypass
- Firmware baseline comparison
- Automated remediation workflows

**Status**: Research phase, scripts exist in `scripts/`

#### 10. **Cloud Integration**
- Remote attestation API
- Centralized firmware database
- Cooperative defense network

**Status**: API sketches in `ideas/cloud_integration/`

## Usage Guide

### Task Runner (pf.py) - PRIMARY INTERFACE

The project uses `pf.py` from [pf-runner](https://github.com/P4X-ng/pf-runner) - a powerful task runner with an intuitive DSL that reads task definitions from `.pf` files.

**All operations should use `./pf.py <task>` as the primary interface.**

#### Task Organization

PhoenixBoot organizes tasks across multiple `.pf` files for clarity:
- **`core.pf`**, **`secure.pf`**, **`workflows.pf`**, **`maint.pf`** - Root compatibility wrappers
- **`components/core/core.pf`** - Essential functionality (build, test, keys, MOK, module signing, UUEFI)
- **`components/secure/secure.pf`** - Advanced Secure Boot operations (enrollment, key management)
- **`components/workflows/workflows.pf`** - Multi-step workflows (artifact creation, CD preparation, USB writing)
- **`components/maint/maint.pf`** - Maintenance tasks (linting, formatting, documentation)

All task files are included in `Pfyfile.pf` and accessible via `./pf.py list`.

#### Core Functionality
#### Core Functionality

Available in `core.pf`:
- Build tasks (setup, build, package ESP)
- Testing tasks (QEMU variants, SecureBoot tests, negative attestation)
- Secure Boot key management (keygen, auth creation)
- MOK (Machine Owner Key) operations
- Module signing
- UUEFI operations
- Validation and verification
- SecureBoot bootable media creation

#### Essential Commands

```bash
# List all available tasks
./pf.py list

# Complete setup: build + package + verify
./pf.py setup

# Build and package ESP
./pf.py esp

# Run QEMU tests
./pf.py test-qemu
./pf.py test-qemu-secure-positive
./pf.py test-qemu-uuefi

# Security environment check (NEW!)
./pf.py secure-env

# Secure Boot key generation
./pf.py secure-keygen
./pf.py secure-make-auth

# MOK management and module signing
./pf.py secure-mok-new
./pf.py os-mok-enroll
./pf.py os-mok-list-keys
MODULE_PATH=/path/to/module ./pf.py os-kmod-sign

# UUEFI operations
./pf.py uuefi-install
./pf.py uuefi-apply
./pf.py uuefi-report

# Validation
./pf.py verify
./pf.py validate-all

# DoD / DISA STIG helpers
./pf.py dod-info
./pf.py dod-stig-check
OUTPUT=out/dod/secure_kernel.config ./pf.py dod-secure-config

# SecureBoot bootable media creation
ISO_PATH=/path/to.iso ./pf.py secureboot-create
ISO_PATH=/path/to.iso USB_DEVICE=/dev/sdX ./pf.py secureboot-create-usb

# Cleanup
./pf.py cleanup
DEEP_CLEAN=1 ./pf.py cleanup
```

### Direct Script Usage

Many operations can also be run directly via bash scripts in the `scripts/` directory. These are compatibility entrypoints; the real script sources now live under `components/*/scripts/`.

```bash
# UUEFI operations
bash scripts/uefi-tools/uuefi-install.sh
bash scripts/uefi-tools/uuefi-apply.sh
bash scripts/uefi-tools/uuefi-report.sh
bash scripts/uefi-tools/host-uuefi-once.sh

# UUEFI v3.0 companion tools
bash scripts/esp-packaging/esp-config-extract.sh # Extract ESP configurations
bash scripts/recovery/nuclear-wipe.sh # Full-system reset helper (EXTREME CAUTION)

# Security environment check
bash scripts/validation/secure-env-check.sh

# Boot management
bash scripts/maintenance/os-boot-clean.sh
bash scripts/mok-management/enroll-mok.sh <cert.crt> <cert.der> [dry_run]
bash scripts/mok-management/mok-list-keys.sh

# Testing
bash scripts/testing/qemu-test.sh
bash scripts/testing/qemu-test-uuefi.sh
```

## Project Structure

```
PhoenixBoot/
├── Root Directory
│ ├── pf.py # Task runner (symlink to pf_universal)
│ ├── Pfyfile.pf # Main task file (includes all .pf files)
│ ├── core.pf # Compatibility wrapper → components/core/core.pf
│ ├── secure.pf # Compatibility wrapper → components/secure/secure.pf
│ ├── workflows.pf # Compatibility wrapper → components/workflows/workflows.pf
│ ├── maint.pf # Compatibility wrapper → components/maint/maint.pf
│ ├── includes/ # Shared include namespace and shell helpers
│ ├── components/ # Component-owned PF files, scripts, and scaffolding
│ ├── docker-compose.yml # Container orchestration
│ ├── phoenixboot-tui.sh # TUI launcher script
│ ├── create-secureboot-bootable-media.sh # Standalone: Create bootable media from ISO
│ ├── DoD/ # Distro-aware DISA STIG and security helpers
│ ├── sign-kernel-modules.sh # User-facing: Sign kernel modules easily
│ └── README.md, QUICKSTART.md, docs/ # Documentation
│
├── containers/ # Container-based architecture (NEW!)
│ ├── build/ # Build container (EDK2, GCC, artifact creation)
│ │ ├── dockerfiles/Dockerfile
│ │ └── quadlets/phoenixboot-build.container
│ ├── test/ # Test container (QEMU, validation)
│ │ ├── dockerfiles/Dockerfile
│ │ └── quadlets/phoenixboot-test.container
│ ├── installer/ # Installer container (ESP, bootable media)
│ │ ├── dockerfiles/Dockerfile
│ │ └── quadlets/phoenixboot-installer.container
│ ├── runtime/ # Runtime container (on-host operations)
│ │ ├── dockerfiles/Dockerfile
│ │ └── quadlets/phoenixboot-runtime.container
│ ├── tui/ # TUI container (interactive interface)
│ │ ├── app/phoenixboot_tui.py
│ │ ├── dockerfiles/Dockerfile
│ │ └── quadlets/phoenixboot-tui.container
│ └── README.md # Container documentation
│
├── staging/ # Production-ready code (source for all builds)
│ ├── src/ # UEFI application source (recovery boot path, KeyEnrollEdk2, UUEFI)
│ ├── boot/ # Compiled EFI binaries (checked in as prebuilt)
│ └── tools/ # Build scripts for EDK2 compilation
│
├── scripts/ # Compatibility script entrypoints
│ ├── build/ # → components/core/scripts/build/
│ │ ├── build-production.sh # Build production artifacts
│ │ ├── build-nuclear-cd.sh # Build recovery CD image
│ │ └── iso-prep.sh # ISO preparation
│ ├── testing/ # → components/core/scripts/testing/
│ │ ├── qemu-test*.sh # Various QEMU test scenarios
│ │ └── run-e2e-tests.sh # End-to-end test runner
│ ├── mok-management/ # MOK & Module Signing
│ │ ├── enroll-mok.sh # Enroll MOK certificates
│ │ ├── mok-*.sh # MOK management scripts
│ │ └── sign-kmods.sh # Sign kernel modules
│ ├── esp-packaging/ # ESP image creation
│ │ ├── esp-package.sh # Package ESP
│ │ └── install_clean_grub_boot.sh # Clean GRUB installation
│ ├── secure-boot/ # SecureBoot operations
│ │ ├── generate-sb-keys.sh # Generate SecureBoot keys
│ │ └── enroll-secureboot.sh # Enroll SecureBoot keys
│ ├── validation/ # Security validation
│ │ ├── secure-env-check.sh # Security environment check
│ │ ├── validate-*.sh # Validation scripts
│ │ └── scan-bootkits.sh # Bootkit detection
│ ├── recovery/ # Recovery operations
│ │ ├── hardware-recovery.sh # Hardware recovery
│ │ ├── reboot-to-metal.sh # Return to normal boot
│ │ └── nuclear-wipe.sh # Full-system reset helper
│ ├── uefi-tools/ # UEFI operations
│ │ ├── uuefi-*.sh # UUEFI operations
│ │ └── uefi_variable_analyzer.py # UEFI variable analysis
│ ├── usb-tools/ # USB media creation
│ ├── qemu/ # QEMU runners
│ └── maintenance/ # Project maintenance
│ ├── lint.sh # Code linting
│ └── format.sh # Code formatting
│
├── utils/ # Python utilities
│ ├── pgmodsign.py # Kernel module signing (canonical location)
│ ├── cert_inventory.py # Certificate management
│ ├── test_efi_parser.py # EFI parser tests
│ └── test_integration.py # Integration tests
│
├── out/ # Build artifacts and test results
│ ├── staging/ # Compiled production binaries
│ ├── staging/ # Compiled production binaries
│ ├── esp/ # ESP images and packaging
│ ├── artifacts/ # Complete artifact packages with docs
│ ├── qemu/ # QEMU test logs and reports
│ └── keys/ # Generated SecureBoot keys
│
├── keys/ # Secure Boot keys (PK, KEK, db, MOK) - legacy location
├── docs/ # Comprehensive documentation
├── tests/ # Test suites
├── experimental/ # NOT alpha-API. Prototypes only (see experimental/README.md)
│ ├── universal-bios/ # Universal BIOS generator prototype
│ ├── universal-bios-plus/ # Newer rewrite (single file)
│ ├── scrapers/ # Distributed hardware scraper prototype
│ ├── hardware-database/ # Sample scraped hardware data
│ ├── scraped-hardware/ # More sample scraped data
│ ├── firmware-recovery-dev/ # Older copy of utils/hardware_firmware_recovery.py
│ ├── cloud-integration/ # Cloud co-op / attestation API sketches
│ ├── nuclear-boot-rust/ # Rust no_std PoC bootloader (source only)
│ └── web/ # Flask hardware-database prototype server
├── ideas/ # Plain-text future ideas (no code)
└── resources/ # Additional resources (KVM, P4X OS ideas, firmware samples)
```

### Key Differences from Before

**Reduced Clutter:**
- Removed 9 wrapper scripts from root (use `./pf.py <task>` instead)
- Removed duplicate `pgmodsign.py` from root (use `utils/pgmodsign.py`)
- All tasks now accessible via unified `./pf.py list`
- Clear task organization across 4 `.pf` files

**Primary Interface:**
- Use `./pf.py <task>` for all operations
- Use `bash scripts/<script>.sh` only for operations not in tasks
- Use `./sign-kernel-modules.sh` for convenient module signing
- Use `./create-secureboot-bootable-media.sh` for turnkey bootable media

**Better Organization:**
- All Python utilities consolidated in `utils/`
- All operational scripts in `scripts/`
- All task definitions in `.pf` files

## Testing

### QEMU Testing

PhoenixBoot includes comprehensive end-to-end QEMU tests that boot real UEFI firmware (OVMF):

```bash
# Run main boot test
./pf.py test-qemu

# Run with Secure Boot enabled
./pf.py test-qemu-secure-positive

# Run Secure Boot strict mode test
./pf.py test-qemu-secure-strict

# Test recovery boot corruption detection (negative attestation)
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
- Basic QEMU boot
- SecureBoot with the recovery boot path
- SecureBoot strict mode
- Corruption detection (negative attestation)
- UUEFI diagnostic tool
- Cloud-Init integration

See `.github/workflows/e2e-tests.yml` for the complete workflow configuration.

### Building from Source

To rebuild UEFI applications from source, you need the EDK2 toolchain:

```bash
# Build the recovery boot app
cd staging/src
chmod +x ../tools/build-nuclear-boot-edk2.sh
../tools/build-nuclear-boot-edk2.sh

# Build UUEFI (fixes the crash issue)
cd staging/src
chmod +x ../tools/build-uuefi.sh
../tools/build-uuefi.sh

# Build KeyEnroll
# (automatically built with the recovery boot build script)
```

Alternatively, force a source rebuild during packaging:

```bash
PG_FORCE_BUILD=1 ./pf.py build-build
```

## Security

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
MODULE_PATH=/lib/modules/.../module.ko ./pf.py os-kmod-sign

# Sign all modules in a directory
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

## Documentation

### Getting Started

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - **START HERE** for new users
- **[Quick Reference](docs/QUICKSTART.md)** - Common commands and workflows
- **[System Architecture](docs/ARCHITECTURE.md)** - Complete architectural overview

### Container Architecture & TUI

- **[Container Architecture](docs/CONTAINER_ARCHITECTURE.md)** - Container-based architecture guide
- **[Container Setup](docs/CONTAINER_SETUP.md)** - Getting started with containers
- **[TUI Guide](docs/TUI_GUIDE.md)** - Interactive terminal interface
- **[Architecture Diagram](docs/ARCHITECTURE_DIAGRAM.md)** - Visual system architecture

### Technical Documentation

- **[Secure Boot Implementation](docs/SECURE_BOOT.md)** - Secure Boot guide
- **[Boot Security Analysis](docs/BOOT_SEQUENCE_AND_ATTACK_SURFACES.md)** - Attack surface analysis
- **[Firmware Recovery](docs/FIRMWARE_RECOVERY.md)** - Recovery procedures
- **[Hardware Access Deep Dive](docs/HARDWARE_ACCESS_DEEP_DIVE.md)** - Hardware-level operations
- **[Security Environment Command](docs/SECURE_ENV_COMMAND.md)** - Security scanning guide
- **[Kernel Hardening Guide](docs/KERNEL_HARDENING_GUIDE.md)** - Kernel security configuration

### UUEFI Documentation

- **[UUEFI v3.1 Features](docs/UUEFI_DEBUG_MODE.md)** - Latest debug diagnostics mode
- **[UUEFI v3.0 Guide](docs/UUEFI_V3_GUIDE.md)** - Complete user guide
- **[UUEFI Enhanced Features](docs/UUEFI_ENHANCED.md)** - Technical reference
- **[Understanding Boot Artifacts](docs/UNDERSTANDING_BOOT_ARTIFACTS.md)** - Keys, shims, and boot concepts

### Testing Documentation

- **[E2E Testing](docs/E2E_TESTING.md)** - End-to-end test guide
- **[Testing Guide](docs/TESTING_GUIDE.md)** - Comprehensive testing documentation
- **[Testing Summary](docs/implementation/TESTING_SUMMARY.md)** - Current test status

### Additional Resources

- **[CI/CD Review Rollup](docs/reviews/CICD_REVIEW_ROLLUP.md)** - Comprehensive project review and status
- **[Feature Status](docs/FEATURES.md)** - Complete feature implementation status
- **[Security Review](docs/reviews/SECURITY_REVIEW_2025-12-07.md)** - Latest security audit
- **[SecureBoot Bootable Media](docs/SECUREBOOT_BOOTABLE_MEDIA.md)** - Create bootable media guide
- **[Container README](containers/README.md)** - Container directory overview
- **[Quick Reference](docs/QUICK_REFERENCE.md)** - Command cheat sheet

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the Apache License 2.0. See LICENSE file for details.

## 🆘 Support

For issues, questions, or support:

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Documentation**: `docs/` directory
- **Alpha scope**: [ALPHA_RELEASE_PLAN.md](ALPHA_RELEASE_PLAN.md)
- **Experimental code (NOT alpha)**: [`experimental/`](experimental/README.md)

## Known Issues

### UUEFI Testing
**Status**: RESOLVED

**Previous Issue**: UUEFI.efi was identical to the recovery boot binary, causing immediate crashes due to strict security checks.

**Current Status**: 
- UUEFI.efi is now a proper diagnostic tool (verified by MD5 checksum)
- Source code reviewed and contains correct implementation
- Build from EDK2 toolchain
- Workflow tasks available for testing: `./pf.py workflow-test-uuefi`

**Testing**: Requires QEMU environment. See `docs/UUEFI_INVESTIGATION.md` for detailed analysis.

**Note**: If you still experience issues, run `./pf.py workflow-test-uuefi` which includes diagnostics and log analysis.

## Alex notes

As the project currently stands, two of the things stand out here as very practical for everyday use and setup of a computer. First is, you can generate secure boot certs very easily (check the pf tasks, there's one to create a new set of keys and put them in EFI, from there you can easily enroll them). For me I use this everyday to spin up new machines with a write-only USB (hardware protected). Barring that I do recommend an actual CD burner that connects via USB, they're super cheap and the medium is immutable once burned, so burn it, check the image hash, and you know you're good to go. If you use PhoenixBoot's image burner you just point it at an ISO, it'll generate all necessary artifacts for secureboot, and you can enroll on first boot. It should also enroll the CD through a shimx64.efi or BOOTX64.efi. Though that's not strictly necessary (I skip that, because secure boot can be touchy with ISOs depending on the drivers you load at boot), but after initial install of the OS boot up to BIOS, enroll those custom keys, takes about 2 minutes, and you're well on your way. In other words, right now it's great as a convenience tool for new boots, or for changing keys on secure boot. 

So SecureBoot is nice but it's also kind of a pain in the ass. Specifically kernel modules have to be signed, and there's a few fairly key ones that I use in ubuntu that come with no signature (lookin' at you apfs.ko). SecureBoot has a signing tool, it'll use you MOK.crt to sign it for your OS, and pop you into a screen to enter a password. Then reboot, at reboot the MOK manager should show up. Enter that password and you've got a PhoenixBoot signed kernel mod. 

Another useful feature right now is, if you don't have an immutable medium available, or even if you just don't feel like getting up and using a USB stick, it creates a new partition with an image burned into it in the ESP. That means you can boot from your boot partition as if there were a USB stick in there. Basically it's a fake little cd, a little trickery there. This can be used for two things (and they're two separate operations on PB) - first is new install of an OS, though again I do recommend an immutable medium, but it's also used as a recovery environment. Currently I'd use the KVM recovery env. KVM/QEMU are there in a minimal recovery environment that has flashrom and a handful of other tools to manage, analyze, and mess with your boot. If you're new to messing with boot stuff (I was when I started this project), a good first start is to totally wipe your BIOS and reinstall it. You can use flashrom from this recovery environment to do that. All of the permissions are set for it, so it shouldn't fail. 

The other modes and other stuff - they need a good amount of testing before they're ready for prime time. By all means feel free to test around and see some of the other utility scripts and workflows we implement - i've been pretty careful not to have anything that might hurt your computer. At worst you'll mess up your boot, which can be flashed again. That said every warning out there tells me there's a possibility of bricking your computer with these things. I've never experienced that, but it sounds like less than fun, so still be careful!

## Roadmap

- [x] Recovery boot path implementation
- [x] Key enrollment automation
- [x] QEMU testing framework
- [x] ESP packaging
- [x] Module signing integration
- [x] UUEFI source code
- [x] Hardware firmware recovery automation (`utils/hardware_firmware_recovery.py`, `hardware.pf`)
- [ ] Build UUEFI binary (requires EDK2)
- [ ] Cloud attestation API
- [ ] P4X OS integration
- [ ] Universal hardware compatibility

---

**Built for a more secure boot process**
