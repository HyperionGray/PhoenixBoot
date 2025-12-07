# QEMU Scripts

Scripts for running QEMU virtual machines.

## QEMU Runners

- `qemu-run.sh` - Standard QEMU runner
- `qemu-run-secure-ui.sh` - QEMU runner with secure UI

## Usage

These scripts are typically used by the testing scripts in `scripts/testing/`.

```bash
# Run basic QEMU
./scripts/qemu/qemu-run.sh

# Run with secure UI
./scripts/qemu/qemu-run-secure-ui.sh
```
