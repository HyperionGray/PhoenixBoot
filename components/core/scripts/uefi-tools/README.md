# UEFI Tools

Scripts for UEFI operations and diagnostics.

## UUEFI Operations

- `uuefi-install.sh` - Install UUEFI to system ESP
- `uuefi-apply.sh` - Set BootNext for one-time UUEFI boot
- `uuefi-report.sh` - Display UEFI system status
- `host-uuefi-once.sh` - Boot UUEFI once on host

## UEFI Variable Analysis

- `uefi_variable_analyzer.py` - Analyze UEFI variables
- `uefi_variable_discovery.py` - Discover UEFI variables

## Usage

```bash
# Install UUEFI
sudo ./scripts/uefi-tools/uuefi-install.sh

# Boot to UUEFI diagnostic tool once
sudo ./scripts/uefi-tools/uuefi-apply.sh

# Check system status
./scripts/uefi-tools/uuefi-report.sh

# Analyze UEFI variables
sudo python3 ./scripts/uefi-tools/uefi_variable_analyzer.py
```
