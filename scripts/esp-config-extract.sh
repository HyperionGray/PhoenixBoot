#!/bin/bash
#
# ESP Configuration Extraction Script
# Extracts tweakable configurations from EFI System Partition
#

set -euo pipefail

echo "🔥 ESP Configuration Extraction Tool"
echo "====================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  This script should be run as root to access ESP"
    echo "   Some features may not work without root access"
fi

# Find ESP mount point
ESP_MOUNT=""
if mount | grep -q "/boot/efi"; then
    ESP_MOUNT="/boot/efi"
elif mount | grep -q "/boot"; then
    ESP_MOUNT="/boot"
else
    echo "❌ Could not find ESP mount point"
    echo "   ESP is typically mounted at /boot/efi or /boot"
    exit 1
fi

echo "✓ Found ESP at: $ESP_MOUNT"
echo ""

# Output file
OUTPUT_FILE="esp_configs_$(date +%Y%m%d_%H%M%S).json"
OUTPUT_DIR="${OUTPUT_DIR:-./}"

echo "📋 Extracting Configuration Files"
echo "=================================="

# Create output structure
cat > "$OUTPUT_DIR/$OUTPUT_FILE" << EOF
{
  "extraction_date": "$(date -Iseconds)",
  "esp_mount": "$ESP_MOUNT",
  "configurations": {
EOF

# Function to extract config file
extract_config() {
    local path="$1"
    local name="$2"
    local full_path="$ESP_MOUNT/$path"
    
    if [ -f "$full_path" ]; then
        echo "  ✓ Found: $path"
        echo "    \"$name\": {" >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "      \"path\": \"$path\"," >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "      \"size\": $(stat -c%s "$full_path")," >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "      \"editable\": true," >> "$OUTPUT_DIR/$OUTPUT_FILE"
        
        # Try to read content (limit to 1KB for safety)
        if [ -r "$full_path" ]; then
            local content=$(head -c 1024 "$full_path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ')
            echo "      \"content_preview\": \"$content\"" >> "$OUTPUT_DIR/$OUTPUT_FILE"
        else
            echo "      \"content_preview\": \"[Permission denied]\"" >> "$OUTPUT_DIR/$OUTPUT_FILE"
        fi
        
        echo "    }," >> "$OUTPUT_DIR/$OUTPUT_FILE"
    fi
}

# Extract common configuration files
extract_config "EFI/PhoenixGuard/config.txt" "phoenixguard_config"
extract_config "EFI/PhoenixGuard/ESP_UUID.txt" "esp_uuid"
extract_config "EFI/BOOT/grub.cfg" "grub_config"
extract_config "EFI/ubuntu/grub.cfg" "ubuntu_grub"
extract_config "loader/loader.conf" "systemd_boot_loader"
extract_config "loader/entries" "systemd_boot_entries"

# Extract boot entries
echo ""
echo "📋 Boot Configuration Variables"
echo "================================"

if [ -d "/sys/firmware/efi/efivars" ]; then
    echo "  ✓ Reading EFI variables..."
    
    # Extract BootOrder
    if [ -f "/sys/firmware/efi/efivars/BootOrder-8be4df61-93ca-11d2-aa0d-00e098032b8c" ]; then
        echo "    \"boot_order\": {" >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "      \"variable\": \"BootOrder\"," >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "      \"editable\": true," >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "      \"description\": \"Order of boot devices\"" >> "$OUTPUT_DIR/$OUTPUT_FILE"
        echo "    }," >> "$OUTPUT_DIR/$OUTPUT_FILE"
    fi
    
    # List all Boot#### entries
    boot_entries=$(find /sys/firmware/efi/efivars -name "Boot[0-9A-F][0-9A-F][0-9A-F][0-9A-F]-*" 2>/dev/null | wc -l)
    echo "  ✓ Found $boot_entries boot entries"
fi

# Close JSON structure (remove trailing comma)
sed -i '$ s/,$//' "$OUTPUT_DIR/$OUTPUT_FILE"
echo "  }" >> "$OUTPUT_DIR/$OUTPUT_FILE"
echo "}" >> "$OUTPUT_DIR/$OUTPUT_FILE"

echo ""
echo "✅ Configuration extraction complete!"
echo "   Output saved to: $OUTPUT_DIR/$OUTPUT_FILE"
echo ""
echo "📋 Summary:"
echo "   ESP Mount: $ESP_MOUNT"
echo "   Output: $OUTPUT_FILE"
echo ""
echo "💡 Next Steps:"
echo "   1. Review extracted configurations"
echo "   2. Use UUEFI menu option 8 to view configs in firmware"
echo "   3. Edit configs in OS and copy back to ESP"
echo "   4. Use scripts/uuefi-apply.sh to boot into UUEFI for changes"
echo ""
echo "⚠️  WARNING: Incorrect ESP configs can prevent booting!"
echo "   Always backup ESP before making changes"
