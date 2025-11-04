# PhoenixBoot Quick Reference

This document provides quick access to the most common PhoenixBoot operations.

## Quick Start Scripts

All scripts are located at the repository root for easy access.

### Initial Setup

```bash
# Bootstrap toolchain and environment
./setup-toolchain.sh

# Generate SecureBoot keys
./generate-secureboot-keys.sh
```

### Kernel Module Signing

```bash
# Sign kernel modules (most prominent - kernel signing made easy!)
./sign-kernel-modules.sh module.ko
./sign-kernel-modules.sh *.ko
./sign-kernel-modules.sh --force module.ko  # Re-sign

# With custom certificate/key
./sign-kernel-modules.sh --cert-path /path/to/cert.pem --key-path /path/to/key.pem module.ko
```

### Building and Packaging

```bash
# Build production artifacts
./build-production.sh

# Package bootable ESP image
./package-esp.sh
```

### SecureBoot and MOK Management

```bash
# Enroll MOK certificate
sudo ./enroll-mok.sh

# Verify SecureBoot status
./verify-secureboot.sh
```

### Testing

```bash
# Run QEMU boot tests
./test-qemu.sh

# Validate ESP contents
./validate-esp.sh
```

### Clean GRUB Installation

```bash
# Install clean GRUB to ESP
# ☠ WARNING: May conflict with existing GRUB configurations!
sudo ./install-clean-grub.sh --esp /boot/efi --root-uuid <UUID>
```

## Advanced Operations

For more advanced operations, use the scripts in the `scripts/` directory:

```bash
# SecureBoot key management
scripts/generate-sb-keys.sh
scripts/create-auth-files.sh
scripts/mok-status.sh
scripts/mok-list-keys.sh

# ESP packaging variants
scripts/esp-package-enroll.sh
scripts/esp-package-minimal.sh
scripts/package-esp-neg-attest.sh

# Testing
scripts/qemu-test-secure-positive.sh
scripts/qemu-test-secure-strict.sh
scripts/qemu-test-uuefi.sh

# Validation
scripts/validate-keys.sh
scripts/verify-esp-robust.sh
scripts/baseline-verify.sh

# Boot configuration
scripts/os-boot-clean.sh
scripts/install_clean_grub_boot.sh

# Recovery and maintenance
scripts/reboot-to-metal.sh
scripts/reboot-to-vm.sh
scripts/scan-bootkits.sh
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
```

## Nuclear Boot Workflow

The nuclear boot workflow provides a clean GRUB installation for recovery scenarios.

### Known Limitations

The nuclear boot workflow may encounter issues with:
- Already-customized Linux distributions with custom GRUB configurations
- Existing GRUB menu entries from distro package managers
- BIOS settings with hardcoded boot entries
- Distro-specific SecureBoot keys

### Best Practices

For optimal results:
1. Back up `/boot/efi/EFI` directory before installation
2. Clear conflicting UEFI boot entries: `efibootmgr -b <num> -B`
3. Ensure BIOS is set to default boot order
4. Verify SecureBoot keys are properly enrolled

See `scripts/install_clean_grub_boot.sh` for detailed documentation.

## Legacy Task Runner (.pf files)

The repository still contains `.pf` files for the `pfy` task runner, but the new root-level scripts provide a simpler, more direct interface. The `.pf` files are maintained for backward compatibility but are no longer the primary way to interact with PhoenixBoot.

## Getting Help

Most scripts support `--help` or `-h` flags for detailed usage information:

```bash
./sign-kernel-modules.sh --help
./install-clean-grub.sh --help
```

For scripts without help flags, check the comments at the top of each script file.
