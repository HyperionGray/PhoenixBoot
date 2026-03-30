# Secure Subprocess Execution in PhoenixBoot Python Tools

This document describes the hardened subprocess pattern now used in active Python operational tools.

## Why this change was made

Two production scripts previously contained TODO markers to replace string-based shell execution:

- `utils/cert_inventory.py`
- `scripts/recovery/phoenix_progressive.py`

The old approach relied on `subprocess.run(..., shell=True)`, which increases command-injection risk and can make argument handling less predictable.

## Current pattern

Both tools now:

- Build commands as argv lists (for example: `["openssl", "x509", ...]`)
- Execute with `shell=False`
- Use `shlex.join(...)` only for logging/display
- Keep command execution behavior equivalent for existing workflows

## Security benefits

- Reduces shell interpretation exposure
- Prevents accidental token/quote expansion by a shell
- Makes command boundaries explicit and easier to audit

## Implementation notes

- `utils/cert_inventory.py` now constructs all OpenSSL invocations as argument arrays.
- `scripts/recovery/phoenix_progressive.py` now normalizes commands to argv before execution.
- Existing operational commands (`make ...`, `sudo make ...`) continue to work while using explicit argv execution.

## Guidance for future scripts

For new Python automation scripts:

1. Prefer `subprocess.run([...], shell=False, ...)`
2. Avoid composing command strings from external input
3. If logging commands, use `shlex.join(argv)` for readable output
4. Reserve `shell=True` for cases that truly require shell features, and document the reason clearly
