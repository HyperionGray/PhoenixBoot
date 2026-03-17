# Command Execution Hardening (2026-03-17)

## What changed

This update hardens command execution in two production Python tools:

- `utils/cert_inventory.py`
- `scripts/recovery/phoenix_progressive.py`

Both now execute subprocesses with argv lists and `shell=False` instead of shell command strings.

## Why this was needed

Both files had explicit TODOs indicating command execution should be refactored away from `shell=True`.
In practice, `shell=True` can introduce:

- accidental shell reinterpretation of arguments
- quoting bugs with paths and argument payloads
- elevated command-injection risk when inputs expand over time

## Implementation details

### `utils/cert_inventory.py`

- Added safe logger initialization that no longer crashes when `/var/log/phoenixguard` is missing.
  - Logging now tries:
    1. `/var/log/phoenixguard`
    2. `out/logs/phoenixguard`
    3. `/tmp/phoenixguard`
- Refactored `run_command()` to accept argument lists and run with `shell=False`.
- Converted all OpenSSL invocations to explicit argv arrays.

### `scripts/recovery/phoenix_progressive.py`

- Added command normalization helper:
  - accepts either string commands (parsed with `shlex.split`)
  - or explicit argv sequences
- Updated `run_command()` to execute normalized argv with `shell=False`.
- Improved error output:
  - printable normalized command via `shlex.join`
  - dedicated `FileNotFoundError` handling
- Removed the stale TODO about future refactoring.

## Behavioral impact

- Existing command flows are preserved.
- Complex Make argument payloads such as:
  - `ARGS=--backup current-firmware.bin`
  - `ARGS=--read suspicious-firmware.bin`
  are now passed safely as single arguments without shell evaluation.

## Follow-up items

- Add automated tests for command normalization and subprocess call contracts.
- Continue migrating any remaining non-demo `shell=True` usage.
