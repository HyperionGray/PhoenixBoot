#!/bin/bash
# PhoenixBoot - Secure Boot Status Detection
# Checks current secure boot status and capability to enable it

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       PhoenixBoot Secure Boot Status & Enablement Check           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if running on UEFI system
check_uefi_system() {
    echo -e "${YELLOW}[1] Checking UEFI System...${NC}"
    if [ -d /sys/firmware/efi ]; then
        echo -e "${GREEN}✓ UEFI system detected${NC}"
        return 0
    else
        echo -e "${RED}✗ Not a UEFI system - Secure Boot not available${NC}"
        echo "  This system uses legacy BIOS"
        return 1
    fi
}

# Check current Secure Boot status
check_secureboot_status() {
    echo -e "\n${YELLOW}[2] Checking Secure Boot Status...${NC}"
    
    if [ -f /sys/firmware/efi/efivars/SecureBoot-* ]; then
        # Read SecureBoot variable
        local sb_file=$(ls /sys/firmware/efi/efivars/SecureBoot-* 2>/dev/null | head -1)
        if [ -n "$sb_file" ]; then
            # Skip first 4 bytes (attributes), read 5th byte for status
            local sb_status=$(od -An -t u1 -j 4 -N 1 "$sb_file" 2>/dev/null | tr -d ' ')
            
            if [ "$sb_status" = "1" ]; then
                echo -e "${GREEN}✓ Secure Boot is ENABLED${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠ Secure Boot is DISABLED${NC}"
                return 1
            fi
        fi
    fi
    
    # Fallback: check with mokutil if available
    if command -v mokutil &>/dev/null; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            echo -e "${GREEN}✓ Secure Boot is ENABLED (via mokutil)${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Secure Boot is DISABLED (via mokutil)${NC}"
            return 1
        fi
    fi
    
    echo -e "${YELLOW}⚠ Unable to determine Secure Boot status${NC}"
    return 2
}

# Check Setup Mode (whether we can enroll keys)
check_setup_mode() {
    echo -e "\n${YELLOW}[3] Checking Setup Mode...${NC}"
    
    if [ -f /sys/firmware/efi/efivars/SetupMode-* ]; then
        local sm_file=$(ls /sys/firmware/efi/efivars/SetupMode-* 2>/dev/null | head -1)
        if [ -n "$sm_file" ]; then
            local sm_status=$(od -An -t u1 -j 4 -N 1 "$sm_file" 2>/dev/null | tr -d ' ')
            
            if [ "$sm_status" = "1" ]; then
                echo -e "${YELLOW}⚠ Setup Mode is ENABLED - can enroll custom keys${NC}"
                return 0
            else
                echo -e "${GREEN}✓ Setup Mode is DISABLED - keys are locked${NC}"
                return 1
            fi
        fi
    fi
    
    echo -e "${YELLOW}⚠ Unable to determine Setup Mode${NC}"
    return 2
}

# Check kernel configuration for BIOS flashing capability
check_kernel_bios_flash_capability() {
    echo -e "\n${YELLOW}[4] Checking Kernel Configuration for BIOS Flashing...${NC}"
    
    local issues=0
    
    # Check /dev/mem access
    if [ -c /dev/mem ]; then
        echo -e "${GREEN}✓ /dev/mem device exists${NC}"
        
        # Try to check if we can actually read it (needs root)
        if [ "$EUID" -eq 0 ]; then
            if dd if=/dev/mem of=/dev/null bs=1 count=1 2>/dev/null; then
                echo -e "${GREEN}✓ /dev/mem is accessible (can read)${NC}"
            else
                echo -e "${RED}✗ /dev/mem exists but is not accessible${NC}"
                issues=$((issues + 1))
            fi
        else
            echo -e "${YELLOW}⚠ Run as root to verify /dev/mem access${NC}"
        fi
    else
        echo -e "${RED}✗ /dev/mem device not available (CONFIG_DEVMEM=n)${NC}"
        echo "  Kernel compiled without /dev/mem support"
        issues=$((issues + 1))
    fi
    
    # Check kernel lockdown status
    if [ -f /sys/kernel/security/lockdown ]; then
        local lockdown_status=$(cat /sys/kernel/security/lockdown 2>/dev/null || echo "unknown")
        
        if echo "$lockdown_status" | grep -q "\[none\]"; then
            echo -e "${GREEN}✓ Kernel lockdown: NONE - BIOS flashing allowed${NC}"
        elif echo "$lockdown_status" | grep -q "\[integrity\]"; then
            echo -e "${YELLOW}⚠ Kernel lockdown: INTEGRITY - May restrict BIOS flashing${NC}"
            echo "  Some BIOS operations may be blocked"
            issues=$((issues + 1))
        elif echo "$lockdown_status" | grep -q "\[confidentiality\]"; then
            echo -e "${RED}✗ Kernel lockdown: CONFIDENTIALITY - BIOS flashing blocked${NC}"
            echo "  Direct hardware access is prevented"
            issues=$((issues + 2))
        fi
    else
        echo -e "${YELLOW}⚠ Kernel lockdown not supported or not enabled${NC}"
    fi
    
    # Check CONFIG_STRICT_DEVMEM
    local config_file="/proc/config.gz"
    if [ -f "$config_file" ]; then
        if zgrep -q "CONFIG_STRICT_DEVMEM=y" "$config_file" 2>/dev/null; then
            echo -e "${YELLOW}⚠ CONFIG_STRICT_DEVMEM=y - /dev/mem access is restricted${NC}"
            echo "  Only system RAM is accessible, not MMIO regions"
            issues=$((issues + 1))
        else
            echo -e "${GREEN}✓ CONFIG_STRICT_DEVMEM not enforced${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Cannot check CONFIG_STRICT_DEVMEM (no /proc/config.gz)${NC}"
    fi
    
    return $issues
}

# Check if kexec is available
check_kexec_availability() {
    echo -e "\n${YELLOW}[5] Checking Kexec Availability...${NC}"
    
    if ! command -v kexec &>/dev/null; then
        echo -e "${RED}✗ kexec command not found${NC}"
        echo "  Install with: sudo apt install kexec-tools"
        return 1
    fi
    
    echo -e "${GREEN}✓ kexec command is available${NC}"
    
    # Check if kernel supports kexec
    local config_file="/proc/config.gz"
    if [ -f "$config_file" ]; then
        if zgrep -q "CONFIG_KEXEC=y" "$config_file" 2>/dev/null; then
            echo -e "${GREEN}✓ CONFIG_KEXEC=y - kernel supports kexec${NC}"
        else
            echo -e "${RED}✗ CONFIG_KEXEC not enabled in kernel${NC}"
            return 1
        fi
    fi
    
    # Check lockdown impact on kexec
    if [ -f /sys/kernel/security/lockdown ]; then
        local lockdown_status=$(cat /sys/kernel/security/lockdown 2>/dev/null || echo "unknown")
        
        if echo "$lockdown_status" | grep -q "\[confidentiality\]"; then
            echo -e "${RED}✗ Kernel lockdown blocks unsigned kexec${NC}"
            echo "  Kexec requires signed kernels in confidentiality mode"
            return 1
        elif echo "$lockdown_status" | grep -q "\[integrity\]"; then
            echo -e "${YELLOW}⚠ Kernel lockdown may require signed kernels for kexec${NC}"
        fi
    fi
    
    return 0
}

# Check for flashrom tool
check_flashrom_available() {
    echo -e "\n${YELLOW}[6] Checking Flashrom Availability...${NC}"
    
    if ! command -v flashrom &>/dev/null; then
        echo -e "${RED}✗ flashrom not installed${NC}"
        echo "  Install with: sudo apt install flashrom"
        return 1
    fi
    
    echo -e "${GREEN}✓ flashrom is installed${NC}"
    
    # Check if running as root (required for flashrom)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}⚠ Run as root to use flashrom${NC}"
        return 2
    fi
    
    return 0
}

# Provide recommendations
provide_recommendations() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                        RECOMMENDATIONS                             ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [ "${SECUREBOOT_ENABLED:-0}" = "1" ]; then
        echo -e "${GREEN}✓ Secure Boot is already enabled - no action needed${NC}"
        echo
        echo "Your system is properly configured with Secure Boot."
        return 0
    fi
    
    echo -e "${YELLOW}Secure Boot Enablement Options:${NC}"
    echo
    
    if [ "${BIOS_FLASH_OK:-0}" = "0" ]; then
        echo -e "${YELLOW}Option 1: Double Kexec Method (RECOMMENDED)${NC}"
        echo "  Your current kernel blocks BIOS flashing."
        echo "  Use the double kexec method to temporarily use a permissive kernel:"
        echo
        echo "  Steps:"
        echo "    1. ./pf.py secureboot-prepare-kexec"
        echo "       (Prepares alternate kernel with relaxed protections)"
        echo
        echo "    2. sudo ./pf.py secureboot-enable-kexec"
        echo "       (Kexec to alternate kernel, enable SecureBoot, kexec back)"
        echo
        echo "  This avoids multiple reboots and maintains system security."
        echo
    else
        echo -e "${GREEN}Option 1: Direct Enablement (AVAILABLE)${NC}"
        echo "  Your kernel allows BIOS access. You can enable Secure Boot directly:"
        echo
        echo "    sudo ./pf.py secureboot-enable-direct"
        echo
    fi
    
    echo -e "${YELLOW}Option 2: Traditional Method (Always Available)${NC}"
    echo "  Enable Secure Boot through BIOS/UEFI settings:"
    echo
    echo "  Steps:"
    echo "    1. Reboot your system"
    echo "    2. Enter BIOS/UEFI setup (usually Del, F2, or F12 during boot)"
    echo "    3. Navigate to Security or Boot settings"
    echo "    4. Enable Secure Boot"
    echo "    5. Save and exit"
    echo
    
    if [ "${SETUP_MODE:-0}" = "1" ]; then
        echo -e "${BLUE}Note: Setup Mode is enabled${NC}"
        echo "  You can enroll custom Secure Boot keys:"
        echo "    ./pf.py secure-keygen          # Generate keys"
        echo "    ./pf.py secure-make-auth       # Create auth files"
        echo "    # Then enroll via KeyEnrollEdk2.efi"
        echo
    fi
}

# Main execution
main() {
    local overall_status=0
    
    # Check UEFI
    if ! check_uefi_system; then
        exit 1
    fi
    
    # Check Secure Boot status
    if check_secureboot_status; then
        SECUREBOOT_ENABLED=1
    else
        SECUREBOOT_ENABLED=0
    fi
    
    # Check Setup Mode
    if check_setup_mode; then
        SETUP_MODE=1
    else
        SETUP_MODE=0
    fi
    
    # Check kernel capability for BIOS flashing
    if check_kernel_bios_flash_capability; then
        BIOS_FLASH_OK=1
    else
        BIOS_FLASH_OK=0
    fi
    
    # Check kexec
    if check_kexec_availability; then
        KEXEC_AVAILABLE=1
    else
        KEXEC_AVAILABLE=0
    fi
    
    # Check flashrom
    check_flashrom_available
    
    # Provide recommendations
    provide_recommendations
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}For detailed kernel hardening analysis:${NC}"
    echo "  ./pf.py kernel-hardening-check"
    echo
    echo -e "${BLUE}For kernel configuration remediation:${NC}"
    echo "  ./pf.py kernel-config-diff"
    echo "  ./pf.py kernel-kexec-guide"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
}

main "$@"
