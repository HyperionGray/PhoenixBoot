# Recovery Scripts

Scripts for system recovery and remediation.

## Risk Guide

| Component | Risk | Most likely outcome | Could happen | Worst case |
| --- | --- | --- | --- | --- |
| `fix-boot-issues.sh` | Medium | Rebuilds boot artifacts and fixes a broken boot path | Manual GRUB/ESP cleanup is still needed | Boot remains unavailable until repaired manually |
| `reboot-to-vm.sh` / Nuclear Boot staging | High | Adds a one-time PhoenixGuard recovery boot and reboots into a recovery VM | ESP or BootNext cleanup is needed afterward | A fragile UEFI setup needs manual EFI repair before normal boot works |
| `reboot-to-metal.sh` | Medium | Removes PhoenixGuard recovery artifacts and restores normal boot | Duplicate recovery entries need manual cleanup | Rebooting without a valid non-PhoenixGuard entry leaves no obvious normal boot target |
| `hardware-recovery.sh` | Critical | Verifies or restores firmware with hardware-level access | Flash access fails or requires external tools | Wrong image or interrupted flash bricks the board |
| `nuclear-wipe.sh` | Critical | Selected disk is erased and the machine needs reinstall | Wrong disk or recovery partition is wiped | Running-system disk is erased and the host becomes immediately unbootable |
| `phoenix_progressive.py` / `autonuke.py` | Varies by step | Guides escalation from safer scans to invasive recovery | A later stage may still need manual repair | Choosing a firmware-writing step can brick hardware |

Use the higher-risk options only as a last resort after less invasive steps, backups, and recovery plans are ready.

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

## Usage

```bash
# Return to normal boot
sudo ./scripts/recovery/reboot-to-metal.sh

# Fix boot issues
./scripts/recovery/fix-boot-issues.sh

# EXTREME CAUTION: Nuclear wipe
sudo ./scripts/recovery/nuclear-wipe.sh
```

**WARNING**: Nuclear Boot, hardware recovery, and nuclear wipe paths can be unpredictable on heavily compromised systems. They should be treated as last-resort workflows, especially when firmware flashing or wiping a disk that may still host the currently running system.
