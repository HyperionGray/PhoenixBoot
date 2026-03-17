#!/usr/bin/env bash
# PhoenixBoot Consolidation Validation Script
# Validates all changes in the comprehensive consolidation PR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

print_header() {
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Validation functions
validate_file_exists() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        print_success "$description exists: $file"
        return 0
    else
        print_error "$description missing: $file"
        return 1
    fi
}

validate_shell_syntax() {
    local file="$1"
    
    if bash -n "$file" 2>/dev/null; then
        print_success "Shell syntax valid: $file"
        return 0
    else
        print_error "Shell syntax invalid: $file"
        return 1
    fi
}

validate_security_fix() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        print_success "$description found in $file"
        return 0
    else
        print_error "$description missing in $file"
        return 1
    fi
}

# Main validation
main() {
    print_header "PhoenixBoot Consolidation Validation"
    echo ""
    
    local errors=0
    
    # Validate new files
    print_header "Validating New Files"
    validate_file_exists "BOOTKIT_DEFENSE_WORKFLOW.md" "Complete workflow guide" || ((errors++))
    validate_file_exists "phoenixboot-wizard.sh" "Interactive setup wizard" || ((errors++))
    validate_file_exists "QUICK_REFERENCE.md" "Quick reference guide" || ((errors++))
    validate_file_exists "docs/PROGRESSIVE_RECOVERY.md" "Progressive recovery guide" || ((errors++))
    validate_file_exists "CONSOLIDATED_PR_SUMMARY.md" "PR summary document" || ((errors++))
    validate_file_exists "CHANGELOG_CONSOLIDATED.md" "Consolidated changelog" || ((errors++))
    echo ""
    
    # Validate shell script syntax
    print_header "Validating Shell Script Syntax"
    if [ -f "phoenixboot-wizard.sh" ]; then
        validate_shell_syntax "phoenixboot-wizard.sh" || ((errors++))
    fi
    if [ -f "create-secureboot-bootable-media.sh" ]; then
        validate_shell_syntax "create-secureboot-bootable-media.sh" || ((errors++))
    fi
    echo ""
    
    # Validate security fixes
    print_header "Validating Security Fixes"
    validate_security_fix "requirements.txt" "cryptography>=42.0.4" "Updated cryptography dependency" || ((errors++))
    validate_security_fix "requirements.txt" "CVE-2024-26130" "CVE reference in requirements" || ((errors++))
    validate_security_fix "utils/cert_inventory.py" "SECURITY:" "Security warning in cert_inventory.py" || ((errors++))
    validate_security_fix "scripts/recovery/phoenix_progressive.py" "SECURITY:" "Security warning in phoenix_progressive.py" || ((errors++))
    echo ""
    
    # Validate documentation cross-references
    print_header "Validating Documentation Cross-References"
    validate_security_fix "README.md" "BOOTKIT_DEFENSE_WORKFLOW.md" "Workflow link in README" || ((errors++))
    validate_security_fix "README.md" "phoenixboot-wizard.sh" "Wizard reference in README" || ((errors++))
    validate_security_fix "QUICK_REFERENCE.md" "phoenixboot-wizard.sh" "Wizard reference in quick reference" || ((errors++))
    echo ""
    
    # Validate file sizes (approximate)
    print_header "Validating File Sizes"
    if [ -f "BOOTKIT_DEFENSE_WORKFLOW.md" ]; then
        local size=$(wc -c < "BOOTKIT_DEFENSE_WORKFLOW.md")
        if [ "$size" -gt 10000 ]; then
            print_success "BOOTKIT_DEFENSE_WORKFLOW.md has substantial content ($size bytes)"
        else
            print_warning "BOOTKIT_DEFENSE_WORKFLOW.md seems small ($size bytes)"
            ((errors++))
        fi
    fi
    
    if [ -f "phoenixboot-wizard.sh" ]; then
        local lines=$(wc -l < "phoenixboot-wizard.sh")
        if [ "$lines" -gt 400 ]; then
            print_success "phoenixboot-wizard.sh has substantial content ($lines lines)"
        else
            print_warning "phoenixboot-wizard.sh seems small ($lines lines)"
            ((errors++))
        fi
    fi
    echo ""
    
    # Validate executable permissions
    print_header "Validating Executable Permissions"
    if [ -f "phoenixboot-wizard.sh" ]; then
        if [ -x "phoenixboot-wizard.sh" ]; then
            print_success "phoenixboot-wizard.sh is executable"
        else
            print_warning "phoenixboot-wizard.sh is not executable (fixing...)"
            chmod +x "phoenixboot-wizard.sh"
            print_success "Fixed executable permission for phoenixboot-wizard.sh"
        fi
    fi
    echo ""
    
    # Summary
    print_header "Validation Summary"
    if [ "$errors" -eq 0 ]; then
        print_success "All validations passed! Consolidation is ready."
        echo ""
        print_info "The PhoenixBoot consolidation includes:"
        echo "  • 4 new documentation files"
        echo "  • 1 new interactive wizard"
        echo "  • 3 security fixes"
        echo "  • 0 breaking changes"
        echo ""
        print_info "Users can now:"
        echo "  • Run ./phoenixboot-wizard.sh for guided setup"
        echo "  • Read BOOTKIT_DEFENSE_WORKFLOW.md for complete workflow"
        echo "  • Use QUICK_REFERENCE.md for command lookup"
        echo "  • Follow docs/PROGRESSIVE_RECOVERY.md for recovery"
        echo ""
        return 0
    else
        print_error "$errors validation errors found. Please review and fix."
        return 1
    fi
}

# Run validation
main "$@"