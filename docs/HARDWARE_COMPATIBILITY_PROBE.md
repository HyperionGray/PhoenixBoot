# Hardware Compatibility Probe

PhoenixBoot includes a host-side compatibility probe to quickly identify
hardware and tooling gaps before running advanced workflows.

## Command

Use the pf task:

```bash
./pf.py hardware-compat-probe
```

Or run the utility directly:

```bash
python3 utils/hardware_compatibility_probe.py \
  --output out/reports/hardware_compatibility_report.json
```

## What it checks

The probe reports:

- UEFI mode and EFI variable accessibility
- Secure Boot state (via `mokutil` when available)
- Presence of key tools for:
  - core secure boot workflows
  - build/test workflows
  - firmware recovery workflows
- OVMF firmware path detection for QEMU-based UEFI testing

## Output

The report is written to:

`out/reports/hardware_compatibility_report.json`

It contains:

- `metadata` (host/kernel/python details)
- `system_state` (UEFI/Secure Boot/root/runtime facts)
- `compatibility` (overall + per-section status)
- `findings` (issues discovered)
- `next_steps` (recommended actions)

## Status labels

- `READY` - all required checks pass
- `PARTIAL` - most required checks pass, but some gaps remain
- `BLOCKED` - too many required checks missing for safe execution
