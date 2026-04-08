# Subprocess Hardening and Repository Cleanup (2026-04-08)

## Summary

This change hardens command execution paths in active Python tooling and removes stale/generated artifacts from version control.

## Feature implemented

### Safe subprocess helper

- Added `utils/subprocess_utils.py` with:
  - `run_command(cmd: Sequence[str], ...)`
  - `format_command(cmd: Sequence[str], use_sudo=False)`
- Commands are executed as argument lists (no `shell=True`), reducing command-injection risk.
- Optional `use_sudo=True` prepends `sudo` in a controlled way.

### Scripts migrated

- `scripts/recovery/phoenix_progressive.py`
  - Refactored internal runner to use list-based commands.
  - Explicit sudo elevation only on operations that require it.
  - Uses repository-root working directory for stable behavior from any launch location.

- `utils/cert_inventory.py`
  - Refactored OpenSSL invocations to argument lists.
  - Replaced shell-string execution with helper-based command execution.

## Documentation updates

- `docs/PROGRESSIVE_RECOVERY.md`
  - Added note that progressive recovery now uses argument-list command execution.

- `utils/README.md`
  - Added “Command execution hardening” section documenting that `cert_inventory.py` and progressive recovery no longer use `shell=True`.

## Repository cleanup

Removed stale/generated tracked files:

- `.bish-index`
- `scripts/.bish-index`
- `utils/.bish-index`
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/**` (generated Rust build/doc output)

Added ignore protections in `.gitignore`:

- `**/target/`
- `**/.bish-index`

## Validation performed

- Verified no remaining `shell=True` in:
  - `scripts/recovery/phoenix_progressive.py`
  - `utils/cert_inventory.py`
- Verified Python bytecode compilation for:
  - `utils/subprocess_utils.py`
  - `scripts/recovery/phoenix_progressive.py`
  - `utils/cert_inventory.py`
- Verified CLI entry points:
  - `python3 scripts/recovery/phoenix_progressive.py --help` (script starts; exits after prompt path)
  - `python3 utils/cert_inventory.py --help`
