#!/bin/bash
#
# Nuclear Wipe Integration Script
# Prepares and launches nwipe for secure disk wiping
#

set -euo pipefail

echo "☢️  PhoenixBoot Nuclear Wipe System"
echo "==================================="
echo ""
echo "⚠️  EXTREME CAUTION: This will PERMANENTLY ERASE data!"
echo "☠ Risk Level: CRITICAL"
echo "   Most likely: The selected disk will be wiped and the machine will need a full reinstall."
echo "   Could happen: You may erase the wrong disk or destroy boot data needed for recovery."
echo "   Worst case: You wipe the currently running system disk and immediately lose a bootable recovery path."
echo "   Use this only as a last resort for decommissioning or severe compromise."
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ This script must be run as root"
    exit 1
fi

validate_device_path() {
    local device="$1"
    if [[ ! "$device" =~ ^/dev/(sd[a-z]{1,4}|nvme[0-9]+n[0-9]+|vd[a-z]{1,2}|mmcblk[0-9]+)$ ]]; then
        echo "❌ Invalid device path format: $device"
        echo "   Expected format: /dev/sdX, /dev/nvmeXnY, /dev/vdX, or /dev/mmcblkX"
        return 1
    fi
    return 0
}

device_contains_running_system() {
    local device="$1"
    lsblk -nrpo NAME,MOUNTPOINT "$device" 2>/dev/null | awk '$2 ~ /^\/$|^\/boot$|^\/boot\/efi$|^\/boot\/grub(2)?$/ { found=1 } END { exit found ? 0 : 1 }'
}

confirm_wipe_target() {
    local device="$1"
    local method="$2"
    local extra_confirmation

    echo "⚠️  FINAL CONFIRMATION"
    echo "   Device: $device"
    echo "   Method: $method"
    echo "   Most likely: Data on $device will be unrecoverable."
    echo "   Could happen: Any OS or recovery partitions on $device will be destroyed."

    if device_contains_running_system "$device"; then
        echo "   Worst case: $device appears to host the currently running system."
        echo "              Wiping it can leave this machine immediately unbootable."
        read -p "Type 'ERASE RUNNING SYSTEM' to accept this risk: " extra_confirmation
        if [ "$extra_confirmation" != "ERASE RUNNING SYSTEM" ]; then
            echo "✅ Cancelled"
            exit 0
        fi
    else
        echo "   Worst case: Boot or recovery partitions on $device may still be needed later."
    fi

    read -p "Type 'WIPE' to confirm: " confirm
    if [ "$confirm" != "WIPE" ]; then
        echo "✅ Cancelled"
        exit 0
    fi

    read -p "Type the exact device path ($device) to confirm target selection: " exact_device
    if [ "$exact_device" != "$device" ]; then
        echo "✅ Cancelled"
        exit 0
    fi
}

# Check if nwipe is installed
if ! command -v nwipe &> /dev/null; then
    echo "⚠️  nwipe not found - attempting to install..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y nwipe
    elif command -v yum &> /dev/null; then
        yum install -y nwipe
    elif command -v dnf &> /dev/null; then
        dnf install -y nwipe
    else
        echo "❌ Could not install nwipe automatically"
        echo "   Please install nwipe manually:"
        echo "   - Debian/Ubuntu: sudo apt-get install nwipe"
        echo "   - RHEL/CentOS: sudo yum install nwipe"
        echo "   - Fedora: sudo dnf install nwipe"
        exit 1
    fi
fi

echo "✅ nwipe is available"
echo ""

# Display disk information
echo "📋 Available Disks:"
echo "==================="
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo ""

# Warning and confirmation
echo "⚠️⚠️⚠️  CRITICAL WARNING  ⚠️⚠️⚠️"
echo ""
echo "Nuclear Wipe will:"
echo "  1. Securely erase all data on selected disk(s)"
echo "  2. Make data unrecoverable"
echo "  3. Take hours to complete"
echo "  4. Require system reinstallation"
echo ""
echo "This is intended for:"
echo "  ✓ Severe malware/rootkit infections"
echo "  ✓ Complete system decommissioning"
echo "  ✓ Security breach response"
echo ""
echo "This is NOT reversible!"
echo ""

# Interactive mode selection
echo "Select operation mode:"
echo "  1. Interactive nwipe (recommended)"
echo "  2. Quick wipe (zeros only, fast)"
echo "  3. DoD Short (3 passes)"
echo "  4. PRNG Stream (cryptographically secure)"
echo "  0. Cancel"
echo ""
read -p "Enter choice [0-4]: " choice

case "$choice" in
    1)
        echo ""
        echo "🚀 Launching nwipe in interactive mode..."
        echo "   Use arrow keys to select disk"
        echo "   Press 'S' to select wipe method"
        echo "   Press 'Enter' to start wipe"
        echo ""
        sleep 2
        nwipe
        ;;
    2)
        echo ""
        read -p "Enter device to wipe (e.g., /dev/sda): " device
        if [ ! -b "$device" ]; then
            echo "❌ Device not found: $device"
            exit 1
        fi

        if ! validate_device_path "$device"; then
            exit 1
        fi
        confirm_wipe_target "$device" "Quick wipe (zeros)"
        
        echo "🚀 Wiping $device..."
        nwipe --autonuke --method=zero --verify=off "$device"
        ;;
    3)
        echo ""
        read -p "Enter device to wipe (e.g., /dev/sda): " device
        if [ ! -b "$device" ]; then
            echo "❌ Device not found: $device"
            exit 1
        fi

        if ! validate_device_path "$device"; then
            exit 1
        fi
        echo "   Time: ~3x disk size (several hours)"
        confirm_wipe_target "$device" "DoD Short (3 passes)"
        
        echo "🚀 Wiping $device with DoD Short..."
        nwipe --autonuke --method=dodshort --verify=last "$device"
        ;;
    4)
        echo ""
        read -p "Enter device to wipe (e.g., /dev/sda): " device
        if [ ! -b "$device" ]; then
            echo "❌ Device not found: $device"
            exit 1
        fi

        if ! validate_device_path "$device"; then
            exit 1
        fi
        echo "   Time: ~1x disk size (many hours)"
        confirm_wipe_target "$device" "PRNG Stream (cryptographically secure)"
        
        echo "🚀 Wiping $device with PRNG..."
        nwipe --autonuke --method=prng --verify=last "$device"
        ;;
    0)
        echo "✅ Cancelled"
        exit 0
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Nuclear wipe complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Reboot system"
echo "   2. Enter BIOS/UEFI and restore settings"
echo "   3. Reinstall operating system"
echo "   4. Re-enroll Secure Boot keys if needed"
echo ""
echo "ℹ️  The system is now clean and ready for fresh installation"
