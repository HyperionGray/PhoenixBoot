# Recovery Scripts

Scripts for system recovery and remediation.

## Hardware Recovery

- `hardware-recovery.sh` - Hardware-level recovery operations
- `recovery-autonuke.sh` - Automated recovery with nuclear option

## Nuclear Options

- `nuclear-wipe.sh` - Complete system wipe (EXTREME CAUTION)
- `autonuke.py` - Automated nuclear remediation

## Boot Recovery

- `reboot-to-metal.sh` - Reboot to normal operation
- `reboot-to-vm.sh` - Reboot to VM environment
- `fix-boot-issues.sh` - Fix common boot issues

## VM-Based Recovery

- `install_kvm_snapshot_jump.sh` - Install KVM snapshot jump
- `phoenix_progressive.py` - Progressive recovery system
- `hardware_compat_probe.py` - Preflight host compatibility checks

## Usage

```bash
# Run preflight compatibility probe
python3 ./scripts/recovery/hardware_compat_probe.py

# Probe only through progressive workflow
python3 ./scripts/recovery/phoenix_progressive.py --probe-only

# Return to normal boot
sudo ./scripts/recovery/reboot-to-metal.sh

# Fix boot issues
./scripts/recovery/fix-boot-issues.sh

# EXTREME CAUTION: Nuclear wipe
sudo ./scripts/recovery/nuclear-wipe.sh
```

**WARNING**: The nuclear-wipe script performs complete system sanitization. Only use in extreme malware situations!
