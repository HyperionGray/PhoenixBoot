# AGENTS.md

## Cursor Cloud specific instructions

### Overview

PhoenixBoot is a UEFI Secure Boot defense system (bash + Python). The primary interface is `./pf <task>`, which is a symlink to the vendored `pf-runner/pf` launcher. The older `./pf.py` shim is kept for the many existing task bodies that say `shell ./pf.py <task>`; it prefers the vendored `./pf` and falls back to a PATH-installed `pf`. Task definitions live in `.pf` files (`Pfyfile.pf`, `core.pf`, `secure.pf`, `workflows.pf`, `hardware.pf`, `maint.pf` and the `components/*/` includes).

### Running services and tasks

- **Task runner**: `./pf list` shows all available tasks. pf-runner is vendored under `pf-runner/`; nothing needs to be installed globally. The Python deps it needs (`fabric`, `lark`, `typer`, `json5`) are listed in `pf-runner/pyproject.toml`; a fresh clone is bootstrapped with `pip install --user -e ./pf-runner`.
- **Build pipeline**: `pf build-setup` (toolchain check) → `pf build-build` (uses prebuilt EFI binaries in `staging/boot/`) → ESP packaging. The build-build step does NOT create `out/staging/`; you must manually copy: `mkdir -p out/staging && cp staging/boot/NuclearBootEdk2.efi out/staging/BootX64.efi && cp staging/boot/KeyEnrollEdk2.efi out/staging/ && cp staging/boot/UUEFI.efi out/staging/`.
- **Key generation**: `pf secure-keygen` creates keys in `keys/`. Keys are needed before ESP packaging (for signing with `sbsign`).
- **ESP packaging**: `scripts/esp-packaging/esp-package.sh` previously had a path bug where `cd "$(dirname "$0")/.."` landed in `scripts/` instead of the project root and `source scripts/lib/common.sh` failed. This has been fixed (see `TODO.md` §"Bugs Fixed in This Assessment"); the script now resolves correctly when invoked from any working directory.
- **QEMU testing**: `pf test-qemu` requires an ESP image at `out/esp/esp.img` and OVMF paths at `out/esp/ovmf_paths.txt`. KVM is not available in cloud VMs — run QEMU with `-cpu max` instead of `-cpu host -enable-kvm`. The test passes when "PhoenixGuard" appears in `out/qemu/serial.log`.

### Lint and test

- **Lint**: `black --check .` and `flake8 --max-line-length 100 utils/` (see `CONTRIBUTING.md`).
- **Tests**: `utils/test_efi_parser.py` depends on a missing `efi_parser` module (not runnable). `utils/test_integration.py` requires compiled C libraries (`libpgmodverify.so`) and cert directories — integration-level only. Shell-based tests exist in `tests/` and `scripts/testing/`.
- **Python utilities**: Import-testable via `python3 -c "from utils.<module> import ..."`. Kernel profiler, firmware checksum DB, and TUI all work.

### System dependencies

The following system packages are required: `qemu-system-x86`, `ovmf`, `mtools`, `dosfstools`, `openssl`, `sbsigntool`, `efitools`, `mokutil`, `gcc`, `parted`.

### Key caveats

- `pf` is now vendored. The launcher is at `pf-runner/pf` and exposed at the repo root as the `./pf` symlink. Use `./pf list` / `./pf <task>`. The vendored copy is pinned to a single version of [`HyperionGray/pf-web-poly-compile-helper-runner`](https://github.com/HyperionGray/pf-web-poly-compile-helper-runner); upgrades are deliberate and manual, not automated.
- Python deps for pf-runner (`fabric`, `lark`, `typer`, `json5`, plus `fastapi`/`uvicorn` for some advanced features) live in `pf-runner/pyproject.toml`. Bootstrap with `pip install --user -e ./pf-runner`. The launcher hunts for a Python that already has the deps; if none is found it errors with "could not find a usable Python 3 runtime" — that's the signal to run the pip install. You can also override via `PF_PYTHON=/path/to/python3 ./pf list`.
- `$HOME/.local/bin` is no longer required for `pf`, but you still need it on `PATH` for other pip-installed user scripts.
- The cloud VM does not have `/dev/kvm`, so QEMU tests must omit `-enable-kvm` and `-cpu host`.
- The cloud VM kernel does not support `vfat` mounts, so `pf build-package-esp` and `pf test-qemu` fail out-of-the-box. Build the ESP image manually using `mtools` (`mmd`, `mcopy`) instead of `mount`. See the build steps used during initial setup for the exact recipe.
- `uuid-runtime` (provides `uuidgen`) must be installed for `pf secure-make-auth` to work. Add it alongside the other system packages listed above.
- The QEMU boot test passes when the `PhoenixGuard` string appears in `out/qemu/serial.log`. Attestation failures (`PG-ATTEST=FAIL`) are expected without SecureBoot enrollment.
