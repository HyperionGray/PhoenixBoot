# Hardware Compatibility Probe

PhoenixBoot now includes a preflight compatibility probe for the progressive
recovery workflow.

## What it checks

`scripts/recovery/hardware_compat_probe.py` validates host prerequisites for:

- UEFI mode presence
- Core tools (`make`, `sudo`, `kexec`, `qemu-system-x86_64`, `flashrom`)
- Kernel/runtime capabilities (`kexec_load_disabled`, IOMMU flags)
- Recovery artifacts (`drivers/G615LPAS.325`, `NuclearBootEdk2.efi`)
- Xen boot artifact availability

It computes readiness per recovery level (`level_1_detect` through
`level_6_hardware`) and highlights blocking issues.

## Usage

```bash
# Human-readable report
python3 scripts/recovery/hardware_compat_probe.py

# JSON report
python3 scripts/recovery/hardware_compat_probe.py --format json

# Save JSON report to disk
python3 scripts/recovery/hardware_compat_probe.py --format json --output out/recovery/hardware_probe.json
```

## Progressive recovery integration

`scripts/recovery/phoenix_progressive.py` now runs the probe before escalation.

```bash
# Standard flow (with preflight probe)
python3 scripts/recovery/phoenix_progressive.py

# Probe only, then exit
python3 scripts/recovery/phoenix_progressive.py --probe-only

# Skip probe (not recommended)
python3 scripts/recovery/phoenix_progressive.py --skip-probe
```
