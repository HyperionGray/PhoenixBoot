# 🖥️ QEMU Testing Scripts

Scripts for testing PhoenixBoot in QEMU virtual machines.

## 📚 Overview

This directory contains scripts for **QEMU virtual machine operations only**. For operations on your physical host machine, see `scripts/secure-boot/`.

### Key Distinction: QEMU vs Host

- **QEMU Operations** (this directory): Testing in virtual machines with OVMF
- **Host Operations** (`scripts/secure-boot/`): Physical machine UEFI firmware operations

## 🚀 QEMU Scripts

### `qemu-run.sh`
Basic QEMU execution for testing.

```bash
./scripts/qemu/qemu-run.sh
```

**Use case**: Quick QEMU boot test without SecureBoot

### `qemu-run-secure-ui.sh`
Launch QEMU with GUI for interactive SecureBoot enablement.

```bash
# Via pf task (recommended)
./pf.py secure-qemu-enable-ui

# Or directly
./scripts/qemu/qemu-run-secure-ui.sh
```

**Features**:
- Opens QEMU GUI window
- Allows manual SecureBoot configuration in OVMF
- Useful for testing key enrollment interactively

**Use case**: Interactive testing and SecureBoot configuration in VM

## 🎯 Common QEMU Testing Workflows

### Workflow 1: Basic Boot Test

```bash
# Build artifacts
./pf.py build-build

# Package ESP
./pf.py build-package-esp

# Test boot in QEMU
./pf.py test-qemu
```

### Workflow 2: SecureBoot Positive Test

```bash
# Ensure keys are generated
./pf.py secure-keygen

# Run SecureBoot test
./pf.py test-qemu-secure-positive
```

### Workflow 3: Interactive SecureBoot Setup in VM

```bash
# Generate keys if needed
./pf.py secure-keygen
./pf.py secure-make-auth

# Launch QEMU GUI for interactive setup
./pf.py secure-qemu-enable-ui
```

### Workflow 4: Full SecureBoot Validation

```bash
# 1. SecureBoot strict mode test
./pf.py test-qemu-secure-strict

# 2. Negative attestation test (corruption detection)
./pf.py test-qemu-secure-negative-attest

# 3. UUEFI application test
./pf.py test-qemu-uuefi
```

## 📖 Related Testing Tasks

All QEMU testing is done via `pf.py` tasks:

### Basic Tests
- `./pf.py test-qemu` - Main boot test
- `./pf.py test-qemu-uuefi` - UUEFI application test

### SecureBoot Tests
- `./pf.py test-qemu-secure-positive` - SecureBoot enabled, valid signatures
- `./pf.py test-qemu-secure-strict` - Strict SecureBoot mode
- `./pf.py test-qemu-secure-negative-attest` - Corruption detection test

### Interactive
- `./pf.py secure-qemu-enable-ui` - QEMU GUI for SecureBoot setup

## 🔧 QEMU Testing Requirements

### Required Software

```bash
# Ubuntu/Debian
sudo apt-get install qemu-system-x86 ovmf

# Fedora
sudo dnf install qemu-system-x86 edk2-ovmf

# Arch
sudo pacman -S qemu-system-x86 edk2-ovmf
```

### Required Files

- OVMF firmware: Usually in `/usr/share/OVMF/` or `/usr/share/edk2/ovmf/`
- ESP image: `out/esp/esp.img` (created by `build-package-esp`)
- Test artifacts: `staging/boot/*.efi`

## 🚫 Common Mistakes

### 1. Using QEMU Scripts on Physical Machine

**Problem**: Trying to run `qemu-run-secure-ui.sh` expecting it to affect host

**Solution**: QEMU scripts only work in VMs. For host operations, use:
- `./pf.py secureboot-check` - Check host SecureBoot
- BIOS/UEFI setup - Enable SecureBoot on host

### 2. Missing OVMF Files

**Problem**: QEMU tests fail with "OVMF not found"

**Solution**:
```bash
# Install OVMF
sudo apt-get install ovmf  # Ubuntu/Debian
sudo dnf install edk2-ovmf  # Fedora

# Verify installation
ls /usr/share/OVMF/
```

### 3. Confusing Test Tasks

**Problem**: Not sure which test to run

**Solution**:
- Start with `test-qemu` for basic boot test
- Progress to `test-qemu-secure-positive` for SecureBoot
- Use `test-qemu-secure-strict` for final validation

## 🔍 Test Output and Logs

QEMU tests generate logs in `out/qemu/`:

```bash
# View test logs
cat out/qemu/serial-test.log

# Check for errors
grep -i error out/qemu/serial-test.log

# View test reports (JUnit format)
cat out/qemu/report-test.xml
```

## 🎓 Understanding QEMU SecureBoot Testing

### Why Test in QEMU?

1. **Safe Testing**: No risk to physical system
2. **Reproducible**: Consistent environment
3. **Fast Iteration**: Quick test cycles
4. **CI/CD Ready**: Automated testing in pipelines

### OVMF vs Physical UEFI

- **OVMF**: Open-source UEFI firmware for QEMU
- **Similar**: Supports SecureBoot, key enrollment
- **Different**: Some hardware-specific features missing
- **Perfect for**: Testing boot chain logic and SecureBoot policies

## 🔗 Related Documentation

- [Testing Tasks](../../core.pf) - All test tasks
- [Container Test](../../containers/test/) - Test container setup
- [SecureBoot Scripts](../secure-boot/README.md) - Host operations
- [ESP Packaging](../esp-packaging/) - Creating test images

## 🐛 Troubleshooting

### QEMU Won't Start

```bash
# Check QEMU installation
which qemu-system-x86_64

# Verify OVMF files
ls -la /usr/share/OVMF/OVMF_CODE.fd

# Try with verbose output
qemu-system-x86_64 --version
```

### SecureBoot Test Fails

```bash
# Ensure keys are generated
./pf.py secure-keygen
ls -la keys/

# Rebuild ESP with keys
./pf.py build-package-esp

# Try with verbose test
QEMU_VERBOSE=1 ./pf.py test-qemu-secure-positive
```

### Test Hangs or Times Out

```bash
# Increase timeout
QEMU_TIMEOUT=600 ./pf.py test-qemu

# Or edit core.pf and increase default timeout
```

## 📞 Support

For QEMU testing issues:
1. Check logs in `out/qemu/`
2. Verify OVMF installation
3. Review this documentation
4. Open GitHub issue with test logs

---

**Made with 🔥 for reliable boot testing**
