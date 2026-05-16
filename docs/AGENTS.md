# AGENTS.md

## Cursor Cloud specific instructions

### Overview

PhoenixBoot is a UEFI Secure Boot defense system (bash + Python). The primary interface is `./pf.py <task>` which delegates to the `pf` task runner (installed from [pf-runner](https://github.com/P4X-ng/pf-runner)). Task definitions live in `.pf` files (`core.pf`, `secure.pf`, `workflows.pf`, `maint.pf`).

### Running services and tasks

- **Task runner**: `./pf.py list` shows all available tasks. `pf` must be on `PATH` (installed to `~/.local/bin/pf`).
- **Build pipeline**: `pf build-setup` (toolchain check) → `pf build-build` (uses prebuilt EFI binaries in `staging/boot/`) → ESP packaging. The build-build step does NOT create `out/staging/`; you must manually copy: `mkdir -p out/staging && cp staging/boot/NuclearBootEdk2.efi out/staging/BootX64.efi && cp staging/boot/KeyEnrollEdk2.efi out/staging/ && cp staging/boot/UUEFI.efi out/staging/`.
- **Key generation**: `pf secure-keygen` creates keys in `keys/`. Keys are needed before ESP packaging (for signing with `sbsign`).
- **ESP packaging**: Shell helpers now live at `includes/lib/common.sh`. ESP packaging entrypoints should run from the project root so that include path resolves correctly, or use `create-secureboot-bootable-media.sh` which already does.
- **QEMU testing**: `pf test-qemu` requires an ESP image at `out/esp/esp.img` and OVMF paths at `out/esp/ovmf_paths.txt`. KVM is not available in cloud VMs — run QEMU with `-cpu max` instead of `-cpu host -enable-kvm`. The test passes when "PhoenixGuard" appears in `out/qemu/serial.log`.

### Lint and test

- **Lint**: `black --check .` and `flake8 --max-line-length 100 utils/` (see `CONTRIBUTING.md`).
- **Tests**: `utils/test_efi_parser.py` depends on a missing `efi_parser` module (not runnable). `utils/test_integration.py` requires compiled C libraries (`libpgmodverify.so`) and cert directories — integration-level only. Shell-based tests exist in `tests/` and `scripts/testing/`.
- **Python utilities**: Import-testable via `python3 -c "from utils.<module> import ..."`. Kernel profiler, firmware checksum DB, and TUI all work.

### System dependencies

The following system packages are required: `qemu-system-x86`, `ovmf`, `mtools`, `dosfstools`, `openssl`, `sbsigntool`, `efitools`, `mokutil`, `gcc`, `parted`.

### Key caveats

- `pf` (the task runner) is NOT a pip package. It is cloned from `https://github.com/P4X-ng/pf-runner` and the `pf-cli-base/pf_parser.py` file is installed as `~/.local/bin/pf` with shebang `#!/usr/bin/env python3`. It requires `fabric` and `lark` pip packages.
- `$HOME/.local/bin` must be on `PATH` for pip-installed scripts and the `pf` runner to work.
- The cloud VM does not have `/dev/kvm`, so QEMU tests must omit `-enable-kvm` and `-cpu host`.
- The cloud VM kernel does not support `vfat` mounts, so `pf build-package-esp` and `pf test-qemu` fail out-of-the-box. Build the ESP image manually using `mtools` (`mmd`, `mcopy`) instead of `mount`. See the build steps used during initial setup for the exact recipe.
- `uuid-runtime` (provides `uuidgen`) must be installed for `pf secure-make-auth` to work. Add it alongside the other system packages listed above.
- The QEMU boot test passes when the `PhoenixGuard` string appears in `out/qemu/serial.log`. Attestation failures (`PG-ATTEST=FAIL`) are expected without SecureBoot enrollment.
