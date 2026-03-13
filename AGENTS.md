# AGENTS.md

## Cursor Cloud specific instructions

### Project overview
PhoenixBoot is a firmware defense system (Secure Boot keys, UEFI diagnostics, kernel module signing). The primary interface is `./pf.py <task>` (the pf-runner task runner). See `README.md` for full docs.

### pf-runner (task runner)
- `pf.py` is a symlink to `/usr/local/bin/pf`, which is the `pf_parser.py` from [pf-runner](https://github.com/P4X-ng/pf-runner).
- If `pf.py` is missing, clone `https://github.com/P4X-ng/pf-runner.git`, copy `pf-cli-base/pf_parser.py` to `/usr/local/bin/pf`, fix the shebang to `#!/usr/bin/env python3`, then `ln -sf /usr/local/bin/pf pf.py` in the workspace root.
- Run `./pf.py list` to see all available tasks.

### Running services
- **Flask Hardware DB server**: `cd web && python3 hardware_database_server.py` (port 5000). Uses SQLite; no external DB needed.
- **TUI**: `./phoenixboot-tui.sh` (requires `textual` and `rich` Python packages, already in `requirements.txt`).

### Lint / test / build
- **Lint (Python)**: `flake8 utils/ --max-line-length 120` and `black --check utils/`. The built-in `./pf.py maint-lint` script exits non-zero due to a pre-existing `set -euo pipefail` + EOF issue — run `flake8`/`black` directly instead.
- **Tests (Python)**: `python3 utils/test_integration.py` (standalone runner, not pytest). Requires `/var/log/phoenixguard/` directory to exist. `utils/test_efi_parser.py` references a non-existent `efi_parser` module and will fail to import.
- **Build**: `./pf.py build-build` (uses pre-built EFI binaries from `staging/boot/`).
- **ESP packaging**: `./pf.py build-package-esp` has a pre-existing path bug (`cd` to `scripts/` then sources `scripts/lib/common.sh`). QEMU tests depend on a working ESP image.
- **Toolchain check**: `./pf.py build-setup` — verifies `gcc`, `qemu-system-x86_64`, `mtools`, `mkfs.fat`, `parted`, `python3`, `mokutil`, `openssl`, and OVMF are installed.

### System dependencies
Installed via apt: `qemu-system-x86`, `ovmf`, `openssl`, `dosfstools`, `mtools`, `sbsigntool`, `efitools`, `shellcheck`, `parted`, `mokutil`.

### Key gotchas
- This is a UEFI firmware project. Many scripts require root or real UEFI hardware. QEMU tests run fine in the VM but require KVM acceleration for full speed (`-enable-kvm`); without `/dev/kvm`, omit that flag or expect slower tests.
- The `pf.py` symlink is **not** checked into git. It must be created as part of dev setup.
- `flask` is not in `requirements.txt` but is needed for the hardware database server in `web/`.
- `PATH` must include `$HOME/.local/bin` for pip-installed tools (`flake8`, `black`, `pytest`, etc.).
