# scripts directory

This folder contains host-side helper scripts organized by category. They do not run inside UEFI; they prepare your system or ESP from Linux.

## Directory Structure

The scripts are grouped by capability so it's easier to find the tool you need.

| Directory | Purpose |
| --- | --- |
| `build/` | Build production artifacts and helper tooling. |
| `testing/` | QEMU-based integration/secure-boot tests. |
| `mok-management/` | Machine Owner Key (MOK) creation, enrollment, and signing helpers. |
| `esp-packaging/` | EFI System Partition (ESP) sizing, packaging, and normalization. |
| `secure-boot/` | SecureBoot key creation, enrollment, and instructions. |
| `validation/` | Static and runtime validation (ESP, keys, bootkits). |
| `recovery/` | Emergency recovery, reboot helpers, and NuclearBoot flows. |
| `usb-tools/` | USB sanitization, preparation, and write helpers. |
| `qemu/` | QEMU launch scripts for secure and UI flows. |
| `uefi-tools/` | Direct UEFI tooling like UUEFI preparation and reports. |
| `maintenance/` | Linting, formatting, cleanup, and structural helpers. |
| `lib/`, `templates/` | Shared helper scripts and templated assets. |
| `git-hooks/` | Repository Git hook helpers (linting, commit policies, pre-commit tooling). |
| `release/` | Release packaging helpers used by `pf build-package-esp` and related flows. |
| `out/` | Artifact staging area (ESP images, keys, docs, etc.). |

## Usage

Most scripts require root privileges when writing to the ESP. Scripts are typically accessed through the task runner (`./pf.py <task>`) rather than directly.

Example:
```bash
# Via task runner (recommended)
./pf.py test-qemu
./pf.py secure-keygen
./pf.py build-package-esp

# Direct execution
sudo ./scripts/secure-boot/generate-sb-keys.sh
bash ./scripts/testing/qemu-test.sh
```

See individual category README files for detailed information about each script.

## CLI & TUI launchers

| Launcher | Purpose |
| --- | --- |
| `./pf.py` | Canonical task runner; pass `./pf.py task-name key=value` to run any script via the DSL. |
| `./phoenixboot-tui.sh` | Launches the terminal UI for the most common tasks in a modern interface. |
| `./phoenixboot-wizard.sh` | Guided three-stage workflow (secure-boot media, clean install, NuclearBoot recovery). |

For CLI-heavy operations (batch builds, QEMU tests, MOK workflows) the `pf.py` task runner keeps arguments organized. When you need a more visual experience, the TUI mirrors the same tasks with buttons and output panels, and the wizard walks you through the full secure install + recovery flow.
