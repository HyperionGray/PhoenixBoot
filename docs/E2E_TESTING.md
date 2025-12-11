# End-to-End Testing Guide

This document describes the comprehensive end-to-end testing framework for PhoenixBoot.

## Overview

PhoenixBoot includes a comprehensive GitHub Actions workflow that tests all major features in QEMU virtual machines. Tests run automatically on every push and pull request.

## Test Coverage

### 1. Basic QEMU Boot Test (`test-basic-boot`)
- **What it tests**: Basic bootability of the ESP image
- **Requirements**: QEMU, OVMF
- **Success criteria**: PhoenixGuard banner appears in serial output
- **Run locally**: `./pf.py test-qemu`

### 2. SecureBoot with NuclearBoot (`test-secureboot`)
- **What it tests**: SecureBoot enforcement and NuclearBoot bootloader
- **Requirements**: QEMU, OVMF, OpenSSL, sbsigntool, efitools
- **Process**:
  1. Generates custom SecureBoot keys (PK, KEK, db)
  2. Enrolls keys into OVMF firmware
  3. Boots with SecureBoot enabled
- **Success criteria**: NuclearBoot boots successfully with SecureBoot active
- **Run locally**: 
  ```bash
  ./pf.py secure-keygen
  ./pf.py secure-make-auth
  ./pf.py secure-enroll-secureboot
  ./pf.py test-qemu-secure-positive
  ```

### 3. SecureBoot Strict Mode (`test-secureboot-strict`)
- **What it tests**: Strict SecureBoot verification mode
- **Requirements**: Same as SecureBoot test
- **Success criteria**: Boot succeeds with strict signature validation
- **Run locally**: `./pf.py test-qemu-secure-strict`

### 4. Corruption Detection (`test-attestation-failure`)
- **What it tests**: NuclearBoot's runtime attestation and corruption detection
- **Process**:
  1. Creates a modified ESP with mismatched hash
  2. Boots with SecureBoot enabled
  3. NuclearBoot detects hash mismatch
- **Success criteria**: Boot fails with `PG-ATTEST=FAIL` message
- **Key feature**: Tests the "test corruption" requirement from the issue
- **Run locally**: 
  ```bash
  ./pf.py build-package-esp-neg-attest
  ./pf.py test-qemu-secure-negative-attest
  ```

### 5. UUEFI Diagnostic Tool (`test-uuefi`)
- **What it tests**: UUEFI diagnostic application
- **Requirements**: QEMU, OVMF, mtools
- **Process**:
  1. Replaces BOOTX64.EFI with UUEFI.efi
  2. Boots and captures diagnostic output
- **Success criteria**: UUEFI produces serial output
- **Run locally**: `./pf.py test-qemu-uuefi`

### 6. Cloud-Init Integration (`test-cloud-init-integration`)
- **What it tests**: Integration with cloud-init for automated VM setup
- **Requirements**: QEMU, OVMF, cloud-init, genisoimage
- **Process**:
  1. Creates cloud-init configuration with username/password
  2. Generates cloud-init ISO
  3. Boots with cloud-init ISO attached
- **Success criteria**: PhoenixBoot boots successfully with cloud-init
- **User credentials**: username: `phoenixuser`, password: `testpass`
- **Run locally**: `./pf.py test-qemu-cloudinit`

## Running Tests Locally

### Prerequisites

Install required dependencies on Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y \
  qemu-system-x86 \
  ovmf \
  mtools \
  dosfstools \
  openssl \
  sbsigntool \
  efitools \
  cloud-init \
  cloud-image-utils \
  genisoimage
```

Install Python dependencies:
```bash
pip install fabric lark
```

### Running Individual Tests

```bash
# Basic boot test
./pf.py test-qemu

# SecureBoot tests (requires key generation first)
./pf.py secure-keygen
./pf.py secure-make-auth
./pf.py secure-enroll-secureboot
./pf.py test-qemu-secure-positive

# Corruption detection test
./pf.py build-package-esp-neg-attest
./pf.py test-qemu-secure-negative-attest

# UUEFI test
./pf.py test-qemu-uuefi

# Cloud-init test
./pf.py test-qemu-cloudinit

# Run all end-to-end tests
./pf.py test-e2e-all
```

### Test Output

All tests generate:
- **Serial logs**: `out/qemu/serial-*.log` - Complete boot output
- **JUnit reports**: `out/qemu/report-*.xml` - Test results in JUnit format
- **Test artifacts**: Keys, ISOs, and other test data in `out/`

## GitHub Actions Workflow

The workflow is defined in `.github/workflows/e2e-tests.yml` and includes:

### Jobs

1. **setup-and-build**: Builds all artifacts once
2. **test-basic-boot**: Tests basic boot
3. **test-secureboot**: Tests SecureBoot enforcement
4. **test-secureboot-strict**: Tests strict mode
5. **test-attestation-failure**: Tests corruption detection
6. **test-uuefi**: Tests UUEFI diagnostic tool
7. **test-cloud-init-integration**: Tests cloud-init setup
8. **test-summary**: Aggregates results and generates summary

### Workflow Triggers

- Push to `main`, `master`, or `develop` branches
- Pull requests to these branches
- Manual trigger via workflow_dispatch

### Artifacts

All test logs and reports are uploaded as GitHub Actions artifacts:
- `build-artifacts`: Compiled binaries and ESP images
- `basic-boot-logs`: Basic boot test logs
- `secureboot-logs`: SecureBoot test logs and keys
- `secureboot-strict-logs`: Strict mode test logs
- `attestation-logs`: Corruption detection test logs
- `uuefi-logs`: UUEFI diagnostic logs
- `cloud-init-logs`: Cloud-init integration logs

## Test Markers

Tests look for specific markers in serial output:

- `PhoenixGuard`: Basic boot success marker
- `[PG-SB=OK]`: SecureBoot is active
- `[PG-ATTEST=OK]`: Runtime attestation passed
- `[PG-ATTEST=FAIL]`: Runtime attestation failed (expected in negative test)
- `[PG-BOOT=FAIL]`: Boot failed due to security violation
- `UUEFI`: UUEFI diagnostic tool marker

## Excluded Tests

Per the issue requirements, Xen boot tests are **not included** in the workflow. Xen hypervisor integration has been removed from the repository.

## Troubleshooting

### Test Failures

1. **"OVMF not found"**: Install OVMF package
2. **"No ESP image"**: Run `./pf.py build-package-esp` first
3. **"KVM not available"**: Tests will run slower without KVM but should still work
4. **Timeout errors**: Increase `PG_QEMU_TIMEOUT` environment variable

### Viewing Test Output

```bash
# View serial log
cat out/qemu/serial.log

# View JUnit report
cat out/qemu/report.xml

# Check for specific markers
grep "PhoenixGuard" out/qemu/serial.log
grep "PG-ATTEST" out/qemu/serial.log
```

## Adding New Tests

To add a new test:

1. Create test script in `scripts/qemu-test-newtest.sh`
2. Add task in `test.pf`:
   ```
   task test-qemu-newtest
     describe Description of new test
     shell bash scripts/qemu-test-newtest.sh
   end
   ```
3. Add job in `.github/workflows/e2e-tests.yml`
4. Update this documentation

## References

- [README.md](../README.md) - Main project documentation
- [SECURE_BOOT.md](SECURE_BOOT.md) - SecureBoot implementation details
- [test.pf](../test.pf) - Test task definitions
- [.github/workflows/e2e-tests.yml](../.github/workflows/e2e-tests.yml) - Workflow definition
