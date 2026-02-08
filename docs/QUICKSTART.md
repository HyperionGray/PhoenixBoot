# PhoenixBoot Quick Reference

This document provides quick access to the most common PhoenixBoot operations.

## 🆕 NEW: Turnkey SecureBoot Bootable Media (RECOMMENDED!)

**The easiest way to create SecureBoot-enabled boot media from any ISO:**

```bash
# One command does everything (DESTRUCTIVE):
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso --usb-device /dev/sdX
# (or: ./pf.py secureboot-create iso_path=/path/to/ubuntu.iso usb_device=/dev/sdX  # alias secureboot-create-usb)
```

See [SECUREBOOT_QUICKSTART.md](SECUREBOOT_QUICKSTART.md) for more details.

## Task Runner (Recommended)

PhoenixBoot uses `pf.py` as the primary task runner. All tasks are defined in `.pf` files.

### List All Available Tasks

```bash
./pf.py list
```

### Initial Setup

```bash
# Bootstrap toolchain and environment
./pf.py build-setup

# Generate SecureBoot keys
./pf.py secure-keygen

# Complete setup workflow
./pf.py setup
```

### Kernel Module Signing

```bash
# Sign a single module
MODULE_PATH=/path/to/module.ko ./pf.py os-kmod-sign

# Sign all modules in a directory (with force)
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign

# Alternative: Use the helper script
./sign-kernel-modules.sh module.ko
./sign-kernel-modules.sh *.ko
./sign-kernel-modules.sh --force module.ko
```

### Building and Packaging

```bash
# Build production artifacts
./pf.py build-build

# Package bootable ESP image
./pf.py build-package-esp

# Convenience: Build + Package
./pf.py esp

# Complete setup: Build + Package + Verify
./pf.py setup
```

### SecureBoot and MOK Management

```bash
# Generate new MOK keypair
./pf.py secure-mok-new

# Enroll MOK certificate
./pf.py os-mok-enroll

# List MOK certificates
./pf.py os-mok-list-keys

# Full MOK workflow
./pf.py mok-flow
```

### Testing

```bash
# Run QEMU boot tests
./pf.py test-qemu

# SecureBoot tests
./pf.py test-qemu-secure-positive
./pf.py test-qemu-secure-strict
./pf.py test-qemu-secure-negative-attest

# UUEFI diagnostic test
./pf.py test-qemu-uuefi

# Validate ESP contents
./pf.py validate-all
./pf.py verify-esp-robust
```

### UUEFI Operations

```bash
# Install UUEFI.efi to system ESP
./pf.py uuefi-install

# Set BootNext for one-time UUEFI boot
./pf.py uuefi-apply

# Display system security status (read-only)
./pf.py uuefi-report
```

### Cleanup

```bash
# Clean build artifacts
./pf.py cleanup

# Deep clean (including ESP)
DEEP_CLEAN=1 ./pf.py cleanup
```

## Direct Script Access

For operations not covered by pf.py tasks, use scripts directly:

```bash
# SecureBoot key management
bash scripts/generate-sb-keys.sh
bash scripts/create-auth-files.sh
bash scripts/mok-status.sh

# ESP packaging variants
bash scripts/esp-package-enroll.sh
bash scripts/esp-package-minimal.sh

# Validation
bash scripts/validate-keys.sh
bash scripts/verify-esp-robust.sh

# Boot configuration
bash scripts/install_clean_grub_boot.sh

# Recovery and maintenance
bash scripts/reboot-to-metal.sh
bash scripts/scan-bootkits.sh
```

## Environment Variables

Common environment variables for customization:

```bash
# Kernel module signing
export KMOD_CERT=/path/to/cert.pem
export KMOD_KEY=/path/to/key.pem

# MOK certificate paths
export MOK_CERT_PEM=out/keys/mok/PGMOK.crt
export MOK_CERT_DER=out/keys/mok/PGMOK.der

# Force source rebuild
export PG_FORCE_BUILD=1

# Task runner environment (optional)
export PFY_FILE=Pfyfile.pf
```

When invoking pf tasks, prefer `mok_cert_pem`, `mok_cert_der`, and `mok_dry_run` as keyword arguments (e.g., `./pf.py os-mok-enroll mok_cert_pem=... mok_dry_run=1`). The legacy uppercase env vars above are still respected by the scripts when you call them directly.

## Common Workflows

### First-Time Setup
```bash
# 1. Setup environment
./pf.py build-setup

# 2. Generate keys
./pf.py secure-keygen
./pf.py secure-make-auth

# 3. Build and package
./pf.py setup

# 4. Test in QEMU
./pf.py test-qemu
```

### MOK Enrollment for Module Signing
```bash
# 1. Generate MOK
./pf.py secure-mok-new

# 2. Enroll MOK (requires reboot)
./pf.py os-mok-enroll

# 3. After reboot, sign modules
MODULE_PATH=/lib/modules/$(uname -r)/kernel/drivers/my_module.ko ./pf.py os-kmod-sign
```

## Getting Help

```bash
# List all available tasks
./pf.py list

# Check sign-kernel-modules.sh options
./sign-kernel-modules.sh --help

# Check script help messages
bash scripts/<script-name>.sh --help  # (where available)
```

For detailed documentation, see:
- `README.md` - Project overview
- `docs/` - Comprehensive documentation
- Script comments - Many scripts have detailed headers
