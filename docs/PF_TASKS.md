# PhoenixBoot .pf Task Organization

## Overview
PhoenixBoot uses `.pf` task files for automation and workflow management. The task system is based on a custom DSL defined in `pf.lark` and executed via `pf.py`.

## Start Here: Workflows (do a full thing)

Most tasks are small building blocks. If you just want the "one command" version, start with these composite/workflow tasks:

```bash
# Build + package + robust verify
./pf.py setup

# Full end-to-end QEMU suite (builds what it needs)
./pf.py test-e2e-all

# Turnkey SecureBoot bootable media from an OS ISO
# (optional) set defaults in phoenixboot.config.local.json5, but prefer passing task arguments
./pf.py secureboot-create iso_path=/path/to/installer.iso
./pf.py secureboot-create iso_path=/path/to/installer.iso usb_device=/dev/sdX  # DESTRUCTIVE (secureboot-create-usb alias)

# ESP/CD artifact bundle + instructions (for offline/immutable media workflows)
./pf.py workflow-complete-esp-cd

# UUEFI smoke test in QEMU (includes diagnostics + log pointers)
./pf.py workflow-test-uuefi

# MOK enrollment workflow (reboot required to finish)
./pf.py mok-flow

# Sign kernel modules after MOK enrollment
./pf.py os-kmod-sign MODULE_PATH=/lib/modules/$(uname -r) FORCE=1

# Host security audit (boot integrity, EFI vars, kernel hardening signals)
./pf.py secure-env
```

**Tip:** Use `./pf.py list` when you need the piecemeal tasks (or want to compose your own workflow).

One-page cheat sheet: `docs/QUICK_REFERENCE.md`.

## Task File Structure

### Core Files
- **Pfyfile.pf** - Main entry point that includes all other task files
- **core.pf** - Core functionality (49 tasks)
  - Build tasks (build-setup, build-build, build-package-esp, etc.)
  - Testing tasks (test-qemu, test-qemu-secure-*, etc.)
  - Secure Boot key management
  - Kernel hardening and configuration
  - Firmware checksum management
  - UUEFI operations
  - Validation tasks
- **secure.pf** - Secure Boot specific tasks (13 tasks)
  - MOK (Machine Owner Key) management
  - Key enrollment and verification
  - Secure Boot enablement
- **maint.pf** - Maintenance tasks (7 tasks)
  - Code formatting and linting
  - Documentation generation
  - Git hooks
- **workflows.pf** - Complex workflows (11 tasks)
  - Artifact creation
  - CD/ISO preparation
  - USB writing
  - Recovery operations

### Total: 80 Tasks across 5 files

## Task Categories

### Build & Setup Tasks
```
build-setup              - Bootstrap toolchain & environment
build-build              - Build production artifacts from staging/
build-package-esp        - Package bootable ESP image
build-package-esp-neg-attest - Create negative attestation ESP
setup                    - Complete project setup
esp                      - Convenience: build + package ESP
```

### Testing Tasks
```
test-qemu                - Main QEMU boot test
test-qemu-secure-positive - Secure Boot positive test
test-qemu-secure-strict  - Secure Boot strict mode test
test-qemu-secure-negative-attest - NuclearBoot corruption detection
test-qemu-uuefi          - UUEFI application test
```

### Secure Boot & Keys
```
secure-keygen            - Generate Secure Boot keypairs (RSA-4096)
secure-make-auth         - Create ESL and AUTH for PK/KEK/db
secure-env               - Comprehensive security environment check
secureboot-check         - Check Secure Boot status
secureboot-prepare-kexec - Preflight check for double kexec enablement (no changes)
secureboot-enable-kexec  - Enable Secure Boot via double kexec
secureboot-enable-direct - Enroll keys via UEFI vars (no kexec; Setup Mode required)
secure-enroll-secureboot - Auto-enroll custom SB keys in OVMF
```

### MOK (Machine Owner Key) Management
```
secure-mok-new           - Generate new PhoenixGuard MOK keypair
os-mok-enroll            - Enroll host MOK for module signing
os-mok-list-keys         - List available MOK certs/keys
secure-mok-status        - Show Secure Boot state and MOKs
secure-mok-verify        - Verify MOK certificate details
secure-mok-find-enrolled - Match local certs to enrolled MOKs
secure-enroll-mok        - Enroll PhoenixGuard MOK certificate
secure-mok-enroll-new    - Generate + enroll MOK (reboot to complete)
secure-unenroll-mok      - Remove PhoenixGuard MOK certificate
mok-flow                 - Full MOK workflow
```

### Kernel Hardening
```
kernel-hardening-check   - Analyze kernel against DISA STIG
kernel-hardening-report  - Generate detailed hardening report
kernel-hardening-baseline - Generate hardened kernel config baseline
kernel-config-diff       - Compare current vs hardened baseline
kernel-config-remediate  - Generate kernel remediation script
kernel-kexec-check       - Check if kexec is available
kernel-kexec-guide       - Show kexec double-jump workflow guide
kernel-profile-list      - List available kernel profiles
kernel-profile-permissive - Generate permissive kernel config
kernel-profile-hardened  - Generate hardened kernel config
kernel-profile-balanced  - Generate balanced kernel config
kernel-profile-compare   - Compare current kernel with profile
```

### Firmware Management
```
firmware-checksum-list   - List all firmware checksums in database
firmware-checksum-verify - Verify firmware file against database
firmware-checksum-add    - Add firmware to checksum database
```

### UUEFI Operations
```
uuefi-install            - Install UUEFI.efi to system ESP
uuefi-apply              - UUEFI apply (set BootNext)
uuefi-report             - UUEFI report (read-only)
```

### Validation & Cleanup
```
validate-all             - Run all validations
verify-esp-robust        - Robust ESP verification
verify                   - Run validation (validate-all + verify-esp-robust)
cleanup                  - Clean build artifacts
os-boot-clean            - Clean stale UEFI boot entries
```

### Maintenance Tasks
```
maint-regen-instructions - Generate copilot-instructions.md
maint-lint               - Run static analysis
maint-format             - Format source code
maint-docs               - Update documentation
maint-clean              - Clean build artifacts
maint-install-git-hooks  - Install pre-push size guard hook
maint-pre-push-check     - Run size guard check locally
```

### Workflow Tasks
```
workflow-artifact-create - Create all necessary artifacts
workflow-cd-prepare      - Prepare bootable CD/ISO
workflow-complete-esp-cd - Complete workflow: artifacts + CD + instructions
workflow-verify-artifacts - Verify all created artifacts
workflow-secureboot-instructions - Generate SecureBoot setup instructions
workflow-test-uuefi      - Test UUEFI application in QEMU
workflow-usb-prepare     - Prepare USB media structure
workflow-usb-write       - Write artifacts to USB drive
workflow-usb-write-dd    - Write image to USB using dd
workflow-recovery-reboot-metal - Reboot to normal metal boot
workflow-recovery-reboot-vm - Reboot to VM/recovery environment
```

### SecureBoot Bootable Media
```
secureboot-create        - Create turnkey SecureBoot bootable media from ISO (optionally write directly via usb_device=...)
secureboot-create-usb    - Alias for secureboot-create with usb_device=<dev> (DESTRUCTIVE)
```

### Key Management
```
secure-keys-centralize   - Centralize keys into out/keys
secure-keys-prune        - Backup + remove legacy key locations
secure-mok-inventory     - JSON inventory of keys and enrollment
secure-der-extract       - Convert DER/PKCS#12 bundle into PEM (set DER_PATH, OUT_DIR, NAME)
secure-package-esp-enroll - Package enrollment ESP
secure-qemu-run-secure-ui - Launch QEMU GUI to enable Secure Boot
```

## Usage

### List all tasks
```bash
./pf.py list
```

### Run a single task
```bash
./pf.py <task-name>
```

### Run multiple tasks in sequence
```bash
./pf.py task1 task2 task3
```

### Pass task inputs (no exports needed)
```bash
./pf.py kernel-profile-compare PROFILE=hardened
./pf.py firmware-checksum-verify FIRMWARE_PATH=/path/to/firmware
```

## Task Dependencies

### Composite Tasks
These tasks call other tasks to create workflows:
- **setup** → build-setup, build-build, build-package-esp, verify-esp-robust
- **esp** → build-build, build-package-esp
- **verify** → validate-all, verify-esp-robust
- **mok-flow** → secure-mok-new, os-mok-enroll
- **workflow-complete-esp-cd** → workflow-artifact-create, workflow-cd-prepare, workflow-secureboot-instructions
- **workflow-test-uuefi** → build-package-esp, test-qemu-uuefi

### Standalone Tasks
60 tasks are standalone and don't call other tasks. These are direct operations that can be used independently or composed into workflows.

## Validation Status

All 77 tasks have been validated:
- ✅ Syntax validated against pf.lark grammar
- ✅ No duplicate task definitions
- ✅ All script references verified
- ✅ Python command invocations fixed
- ✅ Representative tasks tested

## Common Patterns

### Config / Task Inputs
Most tasks accept inputs as environment variables, but you don't need to export them:

- Put them in `phoenixboot.config.local.json5` (preferred). See `docs/CONFIG.md`.
- Or pass them as `key=value` after the task name (one-off).

Common keys:
- `PYTHON` - Python interpreter (default: python3)
- `PROFILE` - Kernel profile name (permissive/hardened/balanced)
- `FIRMWARE_PATH` - Path to firmware file
- `MODULE_PATH` - Path to kernel module file or directory for signing
- `DER_PATH` - Path to DER/PKCS#12 bundle for extraction
- `mok_cert_pem`, `mok_cert_der`, `mok_dry_run` - pf parameter names for the MOK enrollment workflow. The legacy env vars `MOK_CERT_PEM`, `MOK_CERT_DER`, `MOK_DRY_RUN` are still recognized when calling the scripts directly.
- `VENDOR`, `MODEL`, `VERSION` - Firmware metadata
- `usb_device` (pf) - USB device path for writing (legacy `USB_DEVICE`/`USB1_DEV` env vars remain for scripts)
- `iso_path` (pf) - ISO file path for SecureBoot bootable media (legacy `ISO_PATH` env exists only for shell helpers)
- `DEEP_CLEAN` - Enable deep cleaning (1=yes)
- `PG_FORCE_BUILD` - Force rebuild (1=yes)
- `timeout`, `no_kvm` - Optional arguments for `secure-enroll-secureboot`; pass `timeout=SECONDS` to extend the QEMU timeout and `no_kvm=1` to disable KVM acceleration.

### Script Locations
- Build scripts: `scripts/build/`
- Testing scripts: `scripts/testing/`
- Secure Boot scripts: `scripts/secure-boot/`
- MOK management: `scripts/mok-management/`
- UEFI tools: `scripts/uefi-tools/`
- ESP packaging: `scripts/esp-packaging/`
- Validation: `scripts/validation/`
- Maintenance: `scripts/maintenance/`

## Best Practices

1. **Use composite tasks for common workflows** - Tasks like `setup` and `verify` combine multiple steps
2. **Check task descriptions** - Use `./pf.py list` to see what each task does
3. **Verify environment** - Some tasks require specific environment variables
4. **Test before production** - Use QEMU tests before deploying to real hardware
5. **Follow the workflow** - Complex operations like SecureBoot setup have multi-step workflows
