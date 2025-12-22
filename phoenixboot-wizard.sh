#!/usr/bin/env bash
# PhoenixBoot Setup Wizard - Interactive guide for complete bootkit defense
# This script guides users through the complete three-stage workflow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Helper functions
print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║          🔥 PhoenixBoot: Complete Bootkit Defense 🔥         ║"
    echo "║                                                               ║"
    echo "║              Stop Bootkits in Three Stages                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_stage() {
    local stage_num="$1"
    local stage_name="$2"
    local stage_desc="$3"
    
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}STAGE ${stage_num}: ${stage_name}${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${stage_desc}${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

print_error() {
    echo -e "${RED}❌ $*${NC}"
}

print_option() {
    local num="$1"
    local text="$2"
    echo -e "${MAGENTA}  [$num]${NC} $text"
}

ask_continue() {
    local prompt="${1:-Continue}"
    echo ""
    read -p "$(echo -e ${WHITE}${BOLD}${prompt}? [y/N]: ${NC})" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

show_main_menu() {
    clear
    print_header
    
    echo -e "${WHITE}${BOLD}This wizard guides you through complete bootkit defense:${NC}"
    echo ""
    echo -e "${GREEN}  1.${NC} 🔐 ${BOLD}Stage 1:${NC} Create SecureBoot bootable media with custom keys"
    echo -e "${GREEN}  2.${NC} 💿 ${BOLD}Stage 2:${NC} Install OS cleanly with SecureBoot enforced"
    echo -e "${GREEN}  3.${NC} 🔥 ${BOLD}Stage 3:${NC} Clear malicious EFI vars (NuclearBoot)"
    echo ""
    echo -e "${BLUE}  4.${NC} 📚 View complete workflow documentation"
    echo -e "${BLUE}  5.${NC} 🔍 Run security check on current system"
    echo -e "${BLUE}  6.${NC} 🛠️  Advanced options"
    echo ""
    echo -e "${YELLOW}  0.${NC} Exit"
    echo ""
}

stage1_menu() {
    clear
    print_stage "1" "Create SecureBoot Bootable Media" \
        "Generate custom SecureBoot keys and create bootable install media"
    
    echo -e "${WHITE}${BOLD}This stage will:${NC}"
    echo "  ✅ Generate YOUR custom SecureBoot keys (PK, KEK, db)"
    echo "  ✅ Create bootable USB/CD image from your ISO"
    echo "  ✅ Include key enrollment tools on the media"
    echo "  ✅ Set up everything for secure OS installation"
    echo ""
    
    print_info "You will need:"
    echo "  • An OS installation ISO file (e.g., Ubuntu, Fedora, Debian)"
    echo "  • USB flash drive (8GB+) OR blank CD/DVD"
    echo "  • About 5-10 minutes"
    echo ""
    
    if ! ask_continue "Start Stage 1"; then
        return
    fi
    
    # Ask for ISO path
    echo ""
    read -p "$(echo -e ${WHITE}${BOLD}Enter path to your ISO file: ${NC})" iso_path
    
    if [ ! -f "$iso_path" ]; then
        print_error "ISO file not found: $iso_path"
        read -p "Press Enter to continue..."
        return
    fi
    
    print_info "ISO found: $iso_path"
    print_info "Starting bootable media creation..."
    echo ""
    
    # Run the creation script
    if bash ./create-secureboot-bootable-media.sh --iso "$iso_path"; then
        echo ""
        print_success "Bootable media created successfully!"
        echo ""
        print_info "Output files:"
        echo "  • out/esp/secureboot-bootable.img - USB image"
        echo "  • keys/ - Your SecureBoot keys (KEEP SAFE!)"
        echo ""
        print_info "Next steps:"
        echo "  1. Write the image to USB: sudo dd if=out/esp/secureboot-bootable.img of=/dev/sdX bs=4M"
        echo "  2. Boot from the media and install your OS (Stage 2)"
        echo ""
        cat FIRST_BOOT_INSTRUCTIONS.txt 2>/dev/null || true
    else
        print_error "Failed to create bootable media"
        print_info "Check the error messages above for details"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

stage2_menu() {
    clear
    print_stage "2" "Install OS with SecureBoot" \
        "Install your operating system with SecureBoot enforced from the start"
    
    echo -e "${WHITE}${BOLD}Stage 2 Instructions:${NC}"
    echo ""
    echo "1. Boot from your PhoenixBoot media (created in Stage 1)"
    echo "2. Choose your security mode:"
    echo ""
    echo -e "${GREEN}   Option A: Easy Mode${NC}"
    echo "   • Enable SecureBoot in BIOS"
    echo "   • Boot from media"
    echo "   • Select 'Boot from ISO' in GRUB menu"
    echo "   • Install OS normally"
    echo ""
    echo -e "${CYAN}   Option B: Maximum Security${NC}"
    echo "   • Boot with SecureBoot OFF"
    echo "   • Select 'Enroll PhoenixGuard SecureBoot Keys'"
    echo "   • Reboot, enable SecureBoot in BIOS"
    echo "   • Boot from media again"
    echo "   • Select 'Boot from ISO' and install"
    echo ""
    echo "3. After OS installation, sign your kernel modules:"
    echo "   ./sign-kernel-modules.sh"
    echo ""
    echo "4. Verify clean installation:"
    echo "   ./pf.py secure-env"
    echo ""
    
    print_warning "This stage requires physical access to the target system"
    print_info "Follow the on-screen instructions during boot"
    
    echo ""
    read -p "Press Enter to continue..."
}

stage3_menu() {
    clear
    print_stage "3" "Clear Malicious EFI Variables (NuclearBoot)" \
        "Use progressive escalation to remove bootkit infections"
    
    echo -e "${WHITE}${BOLD}Stage 3: Post-Install Protection${NC}"
    echo ""
    echo "Even with SecureBoot enabled, bootkits may have infected your system."
    echo "PhoenixBoot provides progressive escalation to clean your system:"
    echo ""
    echo -e "${GREEN}Level 1:${NC} DETECT   - Software-based scanning (no changes)"
    echo -e "${GREEN}Level 2:${NC} SOFT     - ESP Nuclear Boot ISO (software-only)"
    echo -e "${GREEN}Level 3:${NC} SECURE   - Double-kexec firmware access"
    echo -e "${GREEN}Level 4:${NC} VM       - Reboot to KVM recovery environment"
    echo -e "${GREEN}Level 5:${NC} XEN      - Reboot to Xen dom0 (ultimate isolation)"
    echo -e "${GREEN}Level 6:${NC} HARDWARE - Direct SPI flash recovery"
    echo ""
    
    print_option "1" "Run automatic progressive recovery"
    print_option "2" "Manual inspection with UUEFI tool"
    print_option "3" "Nuclear wipe (EXTREME - for severe infections)"
    print_option "0" "Back to main menu"
    echo ""
    
    read -p "$(echo -e ${WHITE}${BOLD}Select option: ${NC})" -n 1 -r
    echo
    
    case "$REPLY" in
        1)
            echo ""
            print_info "Starting progressive recovery system..."
            echo ""
            if [ -f scripts/recovery/phoenix_progressive.py ]; then
                python3 scripts/recovery/phoenix_progressive.py
            else
                print_error "Progressive recovery script not found"
            fi
            ;;
        2)
            echo ""
            print_info "Installing UUEFI diagnostic tool..."
            ./pf.py uuefi-install 2>/dev/null || {
                print_error "Failed to install UUEFI"
                read -p "Press Enter to continue..."
                return
            }
            
            print_success "UUEFI installed to ESP"
            print_info "Setting up one-time boot..."
            ./pf.py uuefi-apply 2>/dev/null || {
                print_error "Failed to set boot entry"
                read -p "Press Enter to continue..."
                return
            }
            
            print_success "UUEFI configured for next boot"
            echo ""
            print_warning "On next reboot, UUEFI will launch with these features:"
            echo "  • View all EFI variables"
            echo "  • Edit tweakable variables"
            echo "  • Security analysis and suspicious pattern detection"
            echo "  • Vendor bloat removal"
            echo "  • Nuclear wipe options"
            echo ""
            
            if ask_continue "Reboot now"; then
                sudo reboot
            fi
            ;;
        3)
            echo ""
            print_warning "EXTREME CAUTION: Nuclear wipe is PERMANENT!"
            echo ""
            print_info "This will:"
            echo "  • Option 1: Remove vendor bloat (safe)"
            echo "  • Option 2: Reset NVRAM to factory defaults"
            echo "  • Option 3: Guide for secure disk wipe"
            echo "  • Option 4: Complete nuclear wipe (NVRAM + disk)"
            echo ""
            
            if ask_continue "Proceed with nuclear wipe"; then
                sudo bash scripts/recovery/nuclear-wipe.sh
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            sleep 1
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

view_documentation() {
    clear
    print_header
    
    echo -e "${WHITE}${BOLD}📚 Complete Bootkit Defense Workflow${NC}"
    echo ""
    
    if [ -f BOOTKIT_DEFENSE_WORKFLOW.md ]; then
        if command -v less >/dev/null 2>&1; then
            less BOOTKIT_DEFENSE_WORKFLOW.md
        elif command -v more >/dev/null 2>&1; then
            more BOOTKIT_DEFENSE_WORKFLOW.md
        else
            cat BOOTKIT_DEFENSE_WORKFLOW.md
        fi
    else
        print_error "Documentation not found: BOOTKIT_DEFENSE_WORKFLOW.md"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

run_security_check() {
    clear
    print_header
    
    echo -e "${WHITE}${BOLD}🔍 Running Security Check${NC}"
    echo ""
    
    print_info "This comprehensive check will verify:"
    echo "  • EFI variable integrity"
    echo "  • Boot chain integrity (bootloader, kernel, initramfs)"
    echo "  • SecureBoot status and key enrollment"
    echo "  • Kernel security features"
    echo "  • Bootkit detection"
    echo "  • Kernel module signatures"
    echo ""
    
    if ! ask_continue "Run security check"; then
        return
    fi
    
    echo ""
    if [ -f scripts/validation/secure-env-check.sh ]; then
        bash scripts/validation/secure-env-check.sh || true
    else
        print_error "Security check script not found"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

advanced_menu() {
    while true; do
        clear
        print_header
        
        echo -e "${WHITE}${BOLD}🛠️  Advanced Options${NC}"
        echo ""
        print_option "1" "Sign kernel modules (for SecureBoot)"
        print_option "2" "Generate new SecureBoot keys"
        print_option "3" "Enroll MOK (Machine Owner Key)"
        print_option "4" "Run QEMU tests"
        print_option "5" "View task list"
        print_option "6" "Launch interactive TUI"
        print_option "0" "Back to main menu"
        echo ""
        
        read -p "$(echo -e ${WHITE}${BOLD}Select option: ${NC})" -n 1 -r
        echo
        
        case "$REPLY" in
            1)
                echo ""
                bash ./sign-kernel-modules.sh 2>/dev/null || {
                    print_error "Failed to sign kernel modules"
                }
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                print_info "Generating SecureBoot keys..."
                ./pf.py secure-keygen 2>/dev/null && print_success "Keys generated in keys/" || print_error "Failed to generate keys"
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                print_info "Enrolling MOK certificate..."
                ./pf.py os-mok-enroll 2>/dev/null || print_error "Failed to enroll MOK"
                read -p "Press Enter to continue..."
                ;;
            4)
                echo ""
                print_info "Running QEMU tests..."
                ./pf.py test-qemu 2>/dev/null || print_error "QEMU test failed"
                read -p "Press Enter to continue..."
                ;;
            5)
                echo ""
                ./pf.py list 2>/dev/null || print_error "Failed to list tasks"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo ""
                if [ -f phoenixboot-tui.sh ]; then
                    bash ./phoenixboot-tui.sh
                else
                    print_error "TUI script not found"
                    read -p "Press Enter to continue..."
                fi
                ;;
            0)
                return
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Main menu loop
main() {
    while true; do
        show_main_menu
        
        read -p "$(echo -e ${WHITE}${BOLD}Select option: ${NC})" -n 1 -r
        echo
        
        case "$REPLY" in
            1)
                stage1_menu
                ;;
            2)
                stage2_menu
                ;;
            3)
                stage3_menu
                ;;
            4)
                view_documentation
                ;;
            5)
                run_security_check
                ;;
            6)
                advanced_menu
                ;;
            0)
                echo ""
                print_success "Thank you for using PhoenixBoot!"
                print_info "Stop bootkits, period. 🔥"
                echo ""
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Run main menu
main
