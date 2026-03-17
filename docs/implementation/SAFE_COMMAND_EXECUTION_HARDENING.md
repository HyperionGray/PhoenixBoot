# Safe Command Execution Hardening

## Summary

This change hardens command execution in two active PhoenixBoot scripts by removing
`shell=True` execution and moving to explicit argument-list subprocess calls.

Updated files:

- `utils/cert_inventory.py`
- `scripts/recovery/phoenix_progressive.py`

## What Changed

1. **Removed shell-string command execution**
   - Replaced string commands with `Sequence[str]` argument lists.
   - Commands are now passed directly to `subprocess.run([...])`.

2. **Improved command logging**
   - Commands are rendered with shell-safe quoting in logs for readability.
   - Error output now reports the normalized command form.

3. **Hardened logging initialization in cert inventory**
   - If `/var/log/phoenixguard` is unavailable (common in non-root/dev environments),
     logging now falls back to `./cert_inventory.log` instead of failing import.

4. **Added regression tests**
   - New test file: `tests/test_safe_command_execution.py`
   - Verifies argument-list execution and absence of `shell=True` usage.

## Why This Matters

- Reduces command-injection risk surface.
- Improves behavior consistency across environments.
- Keeps tooling usable for developers without root/system log directory access.

## Validation

Run:

```bash
python3 -m unittest tests/test_safe_command_execution.py
python3 -m py_compile utils/cert_inventory.py scripts/recovery/phoenix_progressive.py
```
