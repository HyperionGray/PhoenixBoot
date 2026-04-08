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

### `phoenix_progressive.py` safety model

- Commands now execute with Python `subprocess` argument lists and `shell=False`.
- This removes shell-string expansion risk while preserving existing recovery flow behavior.
- Any future command additions should follow list-argument style:
  - Good: `["make", "scan-bootkits"]`
  - Avoid: `"make scan-bootkits"` unless you intentionally need compatibility parsing.

## Usage

```bash
# Return to normal boot
sudo ./scripts/recovery/reboot-to-metal.sh

# Fix boot issues
./scripts/recovery/fix-boot-issues.sh

# EXTREME CAUTION: Nuclear wipe
sudo ./scripts/recovery/nuclear-wipe.sh
```

**WARNING**: The nuclear-wipe script performs complete system sanitization. Only use in extreme malware situations!
