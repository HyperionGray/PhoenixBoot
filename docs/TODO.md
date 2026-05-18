# PhoenixBoot pf Task Assessment

> **Generated:** 2026-03-18  
> **Environment:** Ubuntu 24.04 (Azure VM), non-root, no EDK2 toolchain, no QEMU/OVMF  
> **pf binary:** Not installed (tasks invoked via `bash scripts/...` directly for testing)

This document records which `pf` tasks were tested, which succeeded, and which failed — along with the reason for failure and any required prerequisites.

---

## ✅ Tested & Succeeded

These tasks executed successfully in the current environment.

| Task | Script/Command | Notes |
|------|---------------|-------|
| `kernel-hardening-check` | `utils/kernel_hardening_analyzer.py --auto` | Scored 61/100 on Azure kernel |
| `kernel-hardening-report` | `utils/kernel_hardening_analyzer.py --auto --format text/json` | Reports saved to `out/reports/` |
| `kernel-hardening-baseline` | `utils/kernel_hardening_analyzer.py --generate-baseline` | Baseline saved to `out/baselines/` |
| `kernel-config-diff` | `utils/kernel_config_remediation.py --diff` | Requires `/boot/config-$(uname -r)` |
| `kernel-kexec-check` | `utils/kernel_config_remediation.py --check-kexec` | Reports kexec not available (expected) |
| `kernel-kexec-guide` | `utils/kernel_config_remediation.py --kexec-guide` | Shows full kexec double-jump guide |
| `kernel-profile-list` | `utils/kernel_config_profiles.py --list` | Lists permissive/hardened/balanced |
| `kernel-profile-permissive` | `utils/kernel_config_profiles.py --profile permissive` | Generates to `out/kernel-profiles/` |
| `kernel-profile-hardened` | `utils/kernel_config_profiles.py --profile hardened` | Generates to `out/kernel-profiles/` |
| `kernel-profile-balanced` | `utils/kernel_config_profiles.py --profile balanced` | Generates to `out/kernel-profiles/` |
| `firmware-checksum-list` | `utils/firmware_checksum_db.py --list` | Returns empty (no entries yet) |
| `secure-keygen` | `scripts/secure-boot/generate-sb-keys.sh` | Keys already present; skips re-gen |
| `secureboot-check` | `scripts/secure-boot/check-secureboot-status.sh` | Reports SB disabled (expected in VM) |
| `secure-env` | `scripts/validation/secure-env-check.sh` | Full security env scan; limited without root |
| `os-mok-list-keys` | `scripts/mok-management/mok-list-keys.sh` | Lists no local MOK certs (none generated) |
| `secure-mok-status` | `scripts/mok-management/mok-status.sh` | Shows system MOK state |
| `secure-mok-find-enrolled` | `scripts/mok-management/mok-find-enrolled.sh` | Shows enrolled MOKs, no local matches |
| `secure-mok-inventory` | `scripts/mok-management/mok-list-keys.sh` | JSON MOK inventory |
| `secure-keys-centralize` | `scripts/secure-boot/keys-centralize.sh` | Centralizes keys to `out/keys/` |
| `uuefi-report` | `scripts/uefi-tools/uuefi-report.sh` | Read-only UEFI variable + boot report (**fixed: cd path bug**) |
| `test-cli` | `scripts/testing/test-phoenixboot-cli.sh` | 11/12 tests pass; test 6 (list) fails without `pf` binary |
| `test-pf` | `scripts/testing/test-pf-tasks.sh` | 19/20 pass; pf.py list fails without `pf` binary |
| `maint-regen-instructions` | `scripts/maintenance/regen-instructions.sh` | Regenerates `copilot-instructions.md` |
| `maint-format` | `scripts/maintenance/format.sh` | Formats Python source files |
| `maint-docs` | `bash -lc 'echo Documentation updated'` | No-op echo only |
| `maint-clean` / `cleanup` | `scripts/maintenance/cleanup.sh` | Cleans build artifacts |
| `maint-install-git-hooks` | `cp scripts/git-hooks/pre-push` | Installs size guard pre-push hook |
| `maint-pre-push-check` | `scripts/git-hooks/pre-push` | Runs size guard check locally |
| `maint-lint` | `scripts/maintenance/lint.sh` | (**fixed: missing `mkdir -p out/lint`**) |
| `verify-esp-robust` | `scripts/validation/verify-esp-robust.sh` | Gracefully fails: no ESP image; reports correctly |
| `secure-keys-prune` | `scripts/secure-boot/keys-centralize.sh --prune` | Prunes legacy key locations |

---

## ❌ Broken / Requires Missing Dependencies

These tasks fail in a standard CI environment. The reason and prerequisites are noted.

### Requires EDK2 Toolchain / Cross-Compiler

| Task | Failing Script | Reason |
|------|---------------|--------|
| `build-build` | `scripts/build/build-production.sh` | Needs EDK2 cross-compiler (ia32/x86_64) |
| `build-setup` | `scripts/maintenance/toolchain-check.sh` | Reports: qemu, mtools, OVMF missing |

### Requires Built EFI Binaries + mtools/ESP tools

| Task | Failing Script | Reason |
|------|---------------|--------|
| `build-package-esp` | `scripts/esp-packaging/esp-package.sh` | Needs `NuclearBootEdk2.efi` from build (**cd path fixed**) |
| `build-package-esp-neg-attest` | `scripts/esp-packaging/package-esp-neg-attest.sh` | Same as above |
| `secure-package-esp-enroll` | `scripts/esp-packaging/esp-package-enroll.sh` | Needs built EFI + auth files (**cd+source path fixed**) |
| `workflow-artifact-create` | (multi-step) | Requires build + keys + ESP |
| `workflow-cd-prepare` | (multi-step) | Requires `workflow-artifact-create` first |
| `workflow-complete-esp-cd` | (multi-step) | Full chain, requires all above |
| `workflow-verify-artifacts` | (multi-step) | No artifacts exist |
| `esp` | `./pf.py build-build build-package-esp` | Requires build |
| `setup` | (multi-step) | Requires build + package + verify |

### Requires QEMU + OVMF

| Task | Failing Script | Reason |
|------|---------------|--------|
| `test-qemu` | `scripts/testing/qemu-test.sh` | `qemu-system-x86_64` not installed; also needs ESP image |
| `test-qemu-secure-positive` | `scripts/testing/qemu-test-secure-positive.sh` | Needs QEMU + OVMF |
| `test-qemu-uuefi` | `scripts/testing/qemu-test-uuefi.sh` | Needs QEMU + OVMF + UUEFI.efi |
| `test-qemu-secure-strict` | `scripts/testing/qemu-test-secure-strict.sh` | Needs QEMU + OVMF |
| `test-qemu-secure-negative-attest` | `scripts/testing/qemu-test-secure-negative-attest.sh` | Needs QEMU + OVMF + corrupted ESP |
| `secure-qemu-enable-ui` | `scripts/qemu/qemu-run-secure-ui.sh` | Needs QEMU GUI |
| `workflow-test-uuefi` | (multi-step) | Needs QEMU + OVMF + ESP |

### Requires efitools (`cert-to-efi-sig-list`, etc.)

| Task | Failing Script | Reason |
|------|---------------|--------|
| `secure-make-auth` | `scripts/secure-boot/create-auth-files.sh` | `cert-to-efi-sig-list` not found; install `efitools` |
| `validate-all` | `scripts/validation/validate-keys.sh` + `validate-esp.sh` | No auth files or ESP image yet |
| `secure-enroll-secureboot` | `scripts/secure-boot/enroll-secureboot.sh` | Needs OVMF + auth files |

### Requires Root / Physical Hardware

| Task | Failing Script | Reason |
|------|---------------|--------|
| `uuefi-install` | `scripts/uefi-tools/uuefi-install.sh` | Needs write access to `/boot/efi` (**cd path fixed**) |
| `uuefi-apply` | `scripts/uefi-tools/uuefi-apply.sh` | Needs `efibootmgr` write access (**cd path fixed**) |
| `secureboot-enable-host-kexec` | `scripts/secure-boot/enable-secureboot-kexec.sh` | Requires root + kexec on physical machine |
| `os-boot-clean` | `scripts/maintenance/os-boot-clean.sh` | Requires root + `efibootmgr` write |
| `os-mok-enroll` | `scripts/mok-management/enroll-mok.sh` | Requires root + `mokutil` + reboot |
| `secure-enroll-mok` | `scripts/mok-management/enroll-mok.sh` | Same as above |
| `secure-mok-enroll-new` | (multi-step) | Requires root + `mokutil` + reboot |
| `mok-flow` | (multi-step) | Requires root + reboot |

### Requires Kernel Module + MOK Key

| Task | Failing Script | Reason |
|------|---------------|--------|
| `os-kmod-sign` | `utils/pgmodsign.py` | Needs `PATH` env var pointing to module; needs MOK key |

### Requires USB Device

| Task | Failing Script | Reason |
|------|---------------|--------|
| `workflow-usb-write` | (multi-step) | Requires `USB_DEVICE` env var pointing to block device (**cd path fixed**) |
| `workflow-usb-prepare` | `scripts/usb-tools/usb-prepare.sh` | Requires `USB_DEVICE` (**cd path fixed**) |
| `workflow-usb-write-dd` | `scripts/usb-tools/usb-write-dd.sh` | Requires `USB_DEVICE` + `IMG_PATH` (**cd path fixed**) |
| `secureboot-create` | `create-secureboot-bootable-media.sh` | Requires `ISO_PATH` env var |
| `secureboot-create-usb` | `create-secureboot-bootable-media.sh` | Requires `ISO_PATH` + `USB_DEVICE` |

### Requires Input / Environment Variables

| Task | Failing Script | Reason |
|------|---------------|--------|
| `firmware-checksum-verify` | `utils/firmware_checksum_db.py` | Requires `FIRMWARE_PATH` env var |
| `firmware-checksum-add` | `utils/firmware_checksum_db.py` | Requires `FIRMWARE_PATH`, `VENDOR`, `MODEL`, `VERSION` |
| `secure-mok-verify` | `scripts/mok-management/mok-verify.sh` | Requires valid MOK cert/key pair |
| `secure-unenroll-mok` | `scripts/mok-management/unenroll-mok.sh` | Requires enrolled MOK to remove |
| `secure-der-extract` | `scripts/secure-boot/der-extract.sh` | Requires `DER_PATH` env var |
| `kernel-profile-compare` | `utils/kernel_config_profiles.py` | Requires `PROFILE` env var |
| `kernel-config-remediate` | `utils/kernel_config_remediation.py` | Requires `/boot/config-$(uname -r)` |

### Requires pf Binary

| Task | Reason |
|------|--------|
| `pf.py list` (all tasks) | `pf` runner binary not installed; install via container or CI |
| `phoenixboot list` | Delegates to `pf.py`, same issue |

### Recovery Tasks (Physical Hardware Only)

| Task | Failing Script | Reason |
|------|---------------|--------|
| `workflow-recovery-reboot-metal` | `scripts/recovery/reboot-to-metal.sh` | Physical host recovery only |
| `workflow-recovery-reboot-vm` | `scripts/recovery/reboot-to-vm.sh` | VM recovery only |

---

## 🔧 Bugs Fixed in This Assessment

The following bugs were discovered and fixed during task testing:

### 1. `scripts/maintenance/lint.sh` — Missing directory creation

**Bug:** Script wrote to `out/lint/c_lint.log` and `out/lint/python_lint.log` without first creating `out/lint/`. This caused `maint-lint` to fail immediately with "No such file or directory".

**Fix:** Added `mkdir -p out/lint` at the top of the script.

### 2. Incorrect `cd` path in 18 scripts — `source scripts/lib/common.sh` fails

**Bug:** Scripts in `scripts/<subdir>/` used `cd "$(dirname "$0")/.."` to navigate one level up (arriving at `scripts/`), then attempted `source scripts/lib/common.sh`. From `scripts/`, this resolved to `scripts/scripts/lib/common.sh` (which doesn't exist), causing immediate failure for all tasks using these scripts.

**Affected tasks:** `uuefi-report`, `uuefi-install`, `uuefi-apply`, `build-package-esp`, `secure-package-esp-enroll`, `workflow-usb-prepare`, `workflow-usb-write-dd`, `verify-esp-robust`-adjacent scripts, and several recovery/mok scripts.

**Fix:** Changed `cd "$(dirname "$0")/.."` to `cd "$(dirname "$0")/../.."` in all 18 affected scripts so CWD lands at the project root, from which `source scripts/lib/common.sh` resolves correctly.

**Fixed scripts:**
- `scripts/usb-tools/usb-prepare.sh`
- `scripts/usb-tools/usb-enroll.sh`
- `scripts/usb-tools/organize-usb1.sh`
- `scripts/usb-tools/usb-write-dd.sh`
- `scripts/mok-management/sign-kmods.sh`
- `scripts/uefi-tools/uuefi-apply.sh`
- `scripts/uefi-tools/uuefi-report.sh`
- `scripts/uefi-tools/uuefi-install.sh`
- `scripts/recovery/fix-boot-issues.sh`
- `scripts/recovery/recovery-autonuke.sh`
- `scripts/esp-packaging/esp-package-enroll-nosudo.sh`
- `scripts/esp-packaging/esp-package-minimal.sh`
- `scripts/esp-packaging/esp-add-allowed-hashes.sh`
- `scripts/esp-packaging/esp-package-nosudo.sh`
- `scripts/esp-packaging/esp-package.sh`
- `scripts/esp-packaging/esp-normalize-secure.sh`
- `scripts/validation/verify-sb.sh`
- `scripts/validation/baseline-verify.sh`

### 3. `scripts/esp-packaging/esp-package-enroll.sh` — Wrong `source` path

**Bug:** This script combined `cd "$(dirname "$0")/.."` (going to `scripts/`) with `source ../../scripts/lib/common.sh`. Even after the `cd` was fixed to go to project root, `source ../../scripts/lib/common.sh` would go two levels _above_ project root.

**Fix:** Changed `source ../../scripts/lib/common.sh` to `source scripts/lib/common.sh`.

---

## 📊 UUEFI Current State

**Current Version:** v3.2.0 (as of 2025-12-22)

The UUEFI diagnostic tool has significantly evolved. The issue noted it was "read-only but still helpful" — that was accurate for v1/v2. The current state:

### v3.2.0 Features (Latest)
- ✅ **Read-only variable reporting** — UEFI variable enumeration (up to 500 variables), categorized by boot/security/hardware/vendor
- ✅ **Security heuristics** — Detects suspicious boot anomalies (up to 50 items)  
- ✅ **Real-time security status reports** — Boot chain integrity, SecureBoot state
- ✅ **Interactive menu** — 9 options for browsing variables, security analysis, configuration
- ✅ **Secure Boot Variable Guarding** (v3.2.0) — Blocks unsafe modifications when SecureBoot is in a broken state (enabled but empty db); prevents hardware lockouts and bricking
- ✅ **Comprehensive variable descriptions** (v3.0.0) — 150+ vendor patterns (ASUS, Intel, MS), human-readable explanations
- ✅ **Editable variables** (v3.0.0) — Non-critical vendor variables can be toggled with safety confirmations; security variables (PK, KEK, db, dbx) are protected from editing
- ✅ **Nuclear Wipe Menu** (v3.0.0) — 4-option sanitization suite: vendor variable wipe, full NVRAM reset, disk wiping guidance, combined nuclear wipe
- ✅ **Validation** (v3.2.0) — `ValidateDbKeys()`, `CheckSecureBootConfiguration()`, `GuardVariableModification()`

### UUEFI Notes
- The `uuefi-report` pf task (read-only host report) was broken by the `cd` path bug; now fixed
- The `uuefi-install` task requires root to write to `/boot/efi`; the `cd` path fix allows it to reach `common.sh`
- The full UUEFI.efi application requires building from EDK2 source (`staging/src/UUEFI.c`)
- UUEFI is no longer read-only — v3.0.0 added safe variable editing and nuclear wipe capabilities

---

## 🔜 Remaining Work

- [ ] Install `efitools` (`cert-to-efi-sig-list`) to unblock `secure-make-auth` and downstream tasks
- [ ] Install `qemu-system-x86_64` + `ovmf` + `mtools` to enable QEMU test suite
- [ ] Add broader host-side validation for `uuefi-install` / `uuefi-apply` before removing the alpha gate (`PHOENIXBOOT_ALPHA_ALLOW_UNTESTED_UUEFI_HOST=1`)
- [ ] Add end-to-end coverage for the DoD CLI delegation paths (`list` / unknown-command fallback) in CI, not just the main CLI smoke script
- [ ] Install EDK2 toolchain to enable `build-build` and UEFI binary compilation
- [ ] Fix `pf` binary installation so `pf.py list` and all task-list UX works correctly (see `.pf_fix.py` for patch details)
- [ ] Add `pf` binary availability check to `scripts/maintenance/toolchain-check.sh`
- [x] Make `phoenixboot` / `phoenixboot-dod` fail loudly with install hints when `pf` exists but is not actually runnable

## Modularity Follow-up

- [x] `utils/kernel_hardening_analyzer.py` - extracted hardening policy/check definitions into `utils/kernel_hardening_policy.py`
- [ ] `dev/tools/hardware_firmware_recovery.py`
- [ ] `utils/hardware_firmware_recovery.py`
- [ ] `components/core/scripts/validation/secure-env-check.sh`
- [ ] `create-secureboot-bootable-media.sh`
