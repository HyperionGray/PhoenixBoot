#!/usr/bin/env bash
set -euo pipefail

# PhoenixGuard KVM Test Installation
# =================================
# Quick test setup for KVM recovery with auto-detected parameters

echo "☠☠ PhoenixGuard KVM Test Installation ☠☠"
echo "============================================"

# Auto-detect system parameters
ROOT_UUID=$(findmnt -n -o UUID / || echo "unknown")
KERNEL_VER=$(uname -r)
VMLINUZ="/boot/vmlinuz-${KERNEL_VER}"
INITRD="/boot/initrd.img-${KERNEL_VER}"
QCOW2="ubuntu-24.04-minimal-cloudimg-amd64.qcow2"

echo "☠ Auto-detected parameters:"
echo "  Root UUID: $ROOT_UUID"
echo "  Kernel: $VMLINUZ"
echo "  Initrd: $INITRD"
echo "  VM Image: $QCOW2"

# Check prerequisites
MISSING=0
if [[ ! -f "$VMLINUZ" ]]; then
    echo "☠ Kernel not found: $VMLINUZ"
    MISSING=1
fi
if [[ ! -f "$INITRD" ]]; then
    echo "☠ Initrd not found: $INITRD"
    MISSING=1
fi
if [[ ! -f "$QCOW2" ]]; then
    echo "☠ VM image not found: $QCOW2"
    MISSING=1
fi

if [[ $MISSING -gt 0 ]]; then
    echo "☠ Prerequisites missing - cannot install KVM recovery"
    exit 1
fi

echo "☠ Prerequisites found"
echo

# Auto-detect GPU
GPU_INFO=$(lspci -nn | grep -E "VGA|Display" | grep -v Intel | head -1 || true)
if [[ -n "$GPU_INFO" ]]; then
    GPU_BDF=$(echo "$GPU_INFO" | cut -d' ' -f1)
    GPU_IDS=$(echo "$GPU_INFO" | grep -o '\[....:....\]' | tail -1 | tr -d '[]')
    echo "☠ Auto-detected GPU:"
    echo "  BDF: $GPU_BDF"
    echo "  IDs: $GPU_IDS"
    echo "  Info: $GPU_INFO"
else
    echo "☠  No discrete GPU found - using Intel integrated"
    GPU_BDF="00:02.0"
    GPU_IDS="8086:7d67"
fi

echo
echo "☠ Installing KVM Snapshot Jump with enhanced recovery..."

# Run the KVM installer with our parameters
sudo ./scripts/install_kvm_snapshot_jump.sh \
    --esp /boot/efi \
    --vmlinuz "$VMLINUZ" \
    --initrd "$INITRD" \
    --root-uuid "$ROOT_UUID" \
    --qcow2 "$PWD/$QCOW2" \
    --loadvm "clean-snap" \
    --gpu-bdf "$GPU_BDF" \
    --gpu-ids "$GPU_IDS"

echo
echo "☠ KVM Test Installation Complete!"
echo "=================================="
echo
echo "☠ Next steps:"
echo "  1. Reboot your system"
echo "  2. Select 'PhoenixGuard Clean Boot' from UEFI menu"
echo "  3. Choose 'KVM Snapshot Jump' from GRUB menu"
echo "  4. Enhanced recovery environment will start with full toolset"
echo "  5. Run 'bootkit-scan' in the VM for comprehensive analysis"
echo
echo "☠ The recovery VM will include:"
echo "  • Python 3 + pip + cryptography libraries"
echo "  • flashrom + chipsec + firmware-tools"
echo "  • radare2 + binwalk + yara for reverse engineering"
echo "  • Hardware analysis: lshw, dmidecode, lspci, etc."
echo "  • Network tools: nmap, tcpdump, wireshark"
echo "  • Clear PASS/FAIL bootkit scanner"
echo
