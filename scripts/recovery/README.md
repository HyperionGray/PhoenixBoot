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

### Progressive Recovery Automation Flags

`phoenix_progressive.py` supports automation-friendly flags:

```bash
# Preview only (no commands executed)
python3 scripts/recovery/phoenix_progressive.py --dry-run --max-level 2

# Auto-approve prompts up to a specific escalation level
python3 scripts/recovery/phoenix_progressive.py --yes --max-level 1
```

Behavior notes:
- Commands are executed using argument lists (no shell string execution).
- Escalation can be bounded with `--max-level` for staged/safe runs.
- Use `RECOVERY_ISO=/path/to/PhoenixGuard-Nuclear-Recovery.iso` to pin Level 2 ISO.

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
