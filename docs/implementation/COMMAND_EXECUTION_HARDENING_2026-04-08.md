# Command Execution Hardening (2026-04-08)

## Summary

Completed previously documented TODO work to reduce command execution risk in active Python tooling by removing `shell=True` usage from two production-facing scripts:

- `components/workflows/scripts/recovery/phoenix_progressive.py`
- `utils/cert_inventory.py`

This change keeps existing behavior while shifting command execution to argument-list based `subprocess.run(..., shell=False)`.

## What Changed

### 1) Progressive recovery runner

In `phoenix_progressive.py`:

- `run_command()` now:
  - Accepts either a string or list.
  - Parses string commands with `shlex.split()`.
  - Executes with `shell=False`.
  - Logs command failures with safely quoted arguments.
- Secure firmware access commands in Level 3 were updated to explicit argument lists.

### 2) Certificate inventory utility

In `utils/cert_inventory.py`:

- `run_command()` now takes `List[str]` and always executes with `shell=False`.
- OpenSSL invocations were converted from interpolated shell strings to explicit argument lists.
- Command logging was preserved, now using `shlex.quote()` for readable, safe diagnostics.

## Why This Matters

- Reduces command injection surface.
- Removes reliance on shell parsing for routine command calls.
- Makes command behavior more deterministic and easier to audit.

## Compatibility Notes

- No task names or user-facing CLI flags changed.
- OpenSSL operations continue to produce the same outputs.
- Recovery flows preserve existing command semantics while improving subprocess safety.
