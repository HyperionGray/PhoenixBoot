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
        
        echo "⚠️  FINAL CONFIRMATION"
        echo "   Device: $device"
        echo "   Method: Quick wipe (zeros)"
        read -p "Type 'WIPE' to confirm: " confirm
        
        if [ "$confirm" != "WIPE" ]; then
            echo "✅ Cancelled"
            exit 0
        fi
        
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
        
        echo "⚠️  FINAL CONFIRMATION"
        echo "   Device: $device"
        echo "   Method: DoD Short (3 passes)"
        echo "   Time: ~3x disk size (several hours)"
        read -p "Type 'WIPE' to confirm: " confirm
        
        if [ "$confirm" != "WIPE" ]; then
            echo "✅ Cancelled"
            exit 0
        fi
        
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
        
        echo "⚠️  FINAL CONFIRMATION"
        echo "   Device: $device"
        echo "   Method: PRNG Stream (cryptographically secure)"
        echo "   Time: ~1x disk size (many hours)"
        read -p "Type 'WIPE' to confirm: " confirm
        
        if [ "$confirm" != "WIPE" ]; then
            echo "✅ Cancelled"
            exit 0
        fi
        
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
