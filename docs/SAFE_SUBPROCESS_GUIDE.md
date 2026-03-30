# Safe Subprocess Execution Guide

This repository now uses a shared helper for secure command execution:

- `utils/safe_subprocess.py`

## Why this exists

Some production scripts previously executed shell command strings. That pattern can
introduce quoting bugs and makes command validation harder. The shared helper
standardizes:

- argv-based execution (no `shell=True`),
- consistent command logging,
- normalized error handling (`CommandExecutionError`).

## What the helper provides

- `normalize_command(command)`:
  - accepts `str` or `Sequence[str]`,
  - returns validated `list[str]`.
- `format_command(argv)`:
  - shell-safe printable command for logs and errors.
- `run_command(...)`:
  - runs subprocesses without shell invocation,
  - supports `cwd`, `timeout`, and optional logger wiring.

## Current production usage

- `utils/cert_inventory.py`
- `scripts/recovery/phoenix_progressive.py`

## Recommended pattern for new scripts

1. Build commands as argv lists:
   - Good: `["openssl", "x509", "-in", cert, "-noout"]`
2. Call `run_command(...)` from `safe_subprocess`.
3. Handle `CommandExecutionError` for user-facing failures.
4. Avoid introducing `shell=True` unless there is a strong, documented reason.
