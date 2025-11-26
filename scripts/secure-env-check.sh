#!/bin/bash
# secure-env-check.sh - PhoenixBoot Comprehensive Security Environment Check
# 
# Checks user environment for security, ensures safety of boot by looking into EFI vars,
# ensuring the integrity of the system, preventing low-level attacks, especially
# around bootkits and signature checking.
#
# This is the main entry point for the secure_env command.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Prefer central venv when available
if [ -x "/home/punk/.venv/bin/python3" ]; then
  PY="/home/punk/.venv/bin/python3"
else
  PY="python3"
fi

# Output directories
OUT_DIR="${REPO_ROOT}/out"
LOG_DIR="${OUT_DIR}/logs"
REPORT_DIR="${OUT_DIR}/reports"
mkdir -p "${LOG_DIR}" "${REPORT_DIR}"

# Timestamp for this scan
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORT_DIR}/secure_env_report_${TIMESTAMP}.txt"
JSON_REPORT="${REPORT_DIR}/secure_env_report_${TIMESTAMP}.json"

# Track overall security status
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0
PASSED_CHECKS=0

# Function to print section header
print_section() {
  echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE} $1${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

# Function to print check result
print_check() {
  local status="$1"
  local message="$2"
  local severity="${3:-INFO}"
  
  case "$status" in
    "PASS")
      echo -e "${GREEN}✓${NC} ${message}"
      ((PASSED_CHECKS++))
      ;;
    "FAIL")
      case "$severity" in
        "CRITICAL")
          echo -e "${RED}✗ CRITICAL:${NC} ${message}"
          ((CRITICAL_ISSUES++))
          ;;
        "HIGH")
          echo -e "${RED}✗ HIGH:${NC} ${message}"
          ((HIGH_ISSUES++))
          ;;
        "MEDIUM")
          echo -e "${YELLOW}⚠ MEDIUM:${NC} ${message}"
          ((MEDIUM_ISSUES++))
          ;;
        "LOW")
          echo -e "${YELLOW}⚠ LOW:${NC} ${message}"
          ((LOW_ISSUES++))
          ;;
      esac
      ;;
    "INFO")
      echo -e "${BLUE}ℹ${NC} ${message}"
      ;;
    "SKIP")
      echo -e "${YELLOW}⊘${NC} ${message} (skipped)"
      ;;
  esac
}

# Function to check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    print_check "INFO" "Not running as root - some checks will be limited"
    return 1
  fi
  return 0
}

# Function to check UEFI/EFI mode
check_uefi_mode() {
  print_section "UEFI/EFI Environment Check"
  
  if [ -d /sys/firmware/efi ]; then
    print_check "PASS" "System is running in UEFI mode"
    
    # Check EFI variables directory
    if [ -d /sys/firmware/efi/efivars ]; then
      local var_count=$(ls -1 /sys/firmware/efi/efivars 2>/dev/null | wc -l)
      print_check "PASS" "EFI variables accessible (${var_count} variables found)"
    else
      print_check "FAIL" "EFI variables directory not accessible" "MEDIUM"
    fi
  else
    print_check "FAIL" "System is NOT running in UEFI mode - legacy BIOS detected" "HIGH"
    return 1
  fi
  
  return 0
}

# Function to check Secure Boot status
check_secure_boot() {
  print_section "Secure Boot Status"
  
  # Check if mokutil is available
  if command -v mokutil &> /dev/null; then
    local sb_state=$(mokutil --sb-state 2>/dev/null || echo "unknown")
    if echo "$sb_state" | grep -q "SecureBoot enabled"; then
      print_check "PASS" "Secure Boot is ENABLED"
    elif echo "$sb_state" | grep -q "SecureBoot disabled"; then
      print_check "FAIL" "Secure Boot is DISABLED - system vulnerable to boot-level attacks" "HIGH"
    else
      print_check "FAIL" "Cannot determine Secure Boot state" "MEDIUM"
    fi
  else
    print_check "SKIP" "mokutil not available - cannot check Secure Boot status"
  fi
  
  # Check for bootx64.efi and shimx64.efi in ESP
  local esp_paths=(/boot/efi /efi)
  for esp in "${esp_paths[@]}"; do
    if [ -d "$esp/EFI" ]; then
      print_check "PASS" "ESP found at $esp"
      
      # Check for shim (SecureBoot bootloader)
      if [ -f "$esp/EFI/BOOT/shimx64.efi" ] || [ -f "$esp/EFI/ubuntu/shimx64.efi" ]; then
        print_check "PASS" "Shim bootloader found (SecureBoot compatible)"
      else
        print_check "INFO" "Shim bootloader not found - may be using custom SecureBoot setup"
      fi
      
      break
    fi
  done
}

# Function to check EFI variables for suspicious modifications
check_efi_variables() {
  print_section "EFI Variables Security Check"
  
  if [ ! -d /sys/firmware/efi/efivars ]; then
    print_check "SKIP" "EFI variables not accessible"
    return
  fi
  
  # Run the UEFI variable analyzer if available
  if [ -f "${SCRIPT_DIR}/uefi_variable_analyzer.py" ]; then
    print_check "INFO" "Running UEFI variable analyzer..."
    local analyzer_output="${LOG_DIR}/uefi_vars_${TIMESTAMP}.log"
    
    if check_root; then
      "${PY}" "${SCRIPT_DIR}/uefi_variable_analyzer.py" > "${analyzer_output}" 2>&1 || true
      print_check "PASS" "UEFI variable analysis complete - see ${analyzer_output}"
    else
      print_check "SKIP" "UEFI variable analysis requires root access"
    fi
  fi
  
  # Check for critical Secure Boot variables
  local sb_vars=("SecureBoot" "SetupMode" "PK" "KEK" "db" "dbx")
  for var in "${sb_vars[@]}"; do
    local var_files=$(find /sys/firmware/efi/efivars -name "${var}-*" 2>/dev/null || true)
    if [ -n "$var_files" ]; then
      print_check "PASS" "Secure Boot variable '${var}' exists"
    else
      if [ "$var" = "SecureBoot" ] || [ "$var" = "PK" ]; then
        print_check "FAIL" "Critical Secure Boot variable '${var}' not found" "HIGH"
      else
        print_check "INFO" "Secure Boot variable '${var}' not found"
      fi
    fi
  done
}

# Function to check boot integrity
check_boot_integrity() {
  print_section "Boot Integrity Check"
  
  # Check kernel signature enforcement
  if [ -f /proc/sys/kernel/module_signature_enforce ]; then
    local sig_enforce=$(cat /proc/sys/kernel/module_signature_enforce)
    if [ "$sig_enforce" = "1" ]; then
      print_check "PASS" "Kernel module signature enforcement is ENABLED"
    else
      print_check "FAIL" "Kernel module signature enforcement is DISABLED" "HIGH"
    fi
  else
    print_check "INFO" "Kernel module signature enforcement status unknown"
  fi
  
  # Check kernel lockdown mode
  if [ -f /sys/kernel/security/lockdown ]; then
    local lockdown=$(cat /sys/kernel/security/lockdown)
    if echo "$lockdown" | grep -q "\[integrity\]"; then
      print_check "PASS" "Kernel lockdown mode: integrity (recommended)"
    elif echo "$lockdown" | grep -q "\[confidentiality\]"; then
      print_check "PASS" "Kernel lockdown mode: confidentiality (maximum security)"
    elif echo "$lockdown" | grep -q "\[none\]"; then
      print_check "FAIL" "Kernel lockdown is DISABLED - system vulnerable to attacks" "MEDIUM"
    else
      print_check "INFO" "Kernel lockdown status: $lockdown"
    fi
  else
    print_check "SKIP" "Kernel lockdown not supported on this kernel"
  fi
  
  # Check bootloader (GRUB) integrity
  local grub_cfg="/boot/grub/grub.cfg"
  if [ -f "$grub_cfg" ]; then
    print_check "PASS" "GRUB configuration found at $grub_cfg"
    
    # Check if GRUB has password protection
    if grep -q "^password\|^set superusers" "$grub_cfg" 2>/dev/null; then
      print_check "PASS" "GRUB has password protection enabled"
    else
      print_check "FAIL" "GRUB does not have password protection - boot parameters can be modified" "MEDIUM"
    fi
  else
    print_check "INFO" "GRUB configuration not found at standard location"
  fi
  
  # Check initramfs integrity
  local kernel_version=$(uname -r)
  local initrd_path="/boot/initrd.img-${kernel_version}"
  if [ -f "$initrd_path" ]; then
    print_check "PASS" "Initramfs found for kernel ${kernel_version}"
  else
    print_check "FAIL" "Initramfs not found for current kernel" "MEDIUM"
  fi
}

# Function to check kernel security features
check_kernel_security() {
  print_section "Kernel Security Features"
  
  local kernel_version=$(uname -r)
  print_check "INFO" "Running kernel: ${kernel_version}"
  
  # Check kernel config if available
  local config_files=("/proc/config.gz" "/boot/config-${kernel_version}")
  local config_found=false
  
  for config in "${config_files[@]}"; do
    if [ -f "$config" ]; then
      config_found=true
      print_check "PASS" "Kernel config found at $config"
      
      # Extract config
      local kernel_config
      if [[ "$config" == *.gz ]]; then
        kernel_config=$(zcat "$config")
      else
        kernel_config=$(cat "$config")
      fi
      
      # Check important security options
      check_kernel_option "$kernel_config" "CONFIG_MODULE_SIG" "Module signature verification"
      check_kernel_option "$kernel_config" "CONFIG_MODULE_SIG_FORCE" "Force module signature verification"
      check_kernel_option "$kernel_config" "CONFIG_SECURITY_LOCKDOWN_LSM" "Kernel lockdown LSM"
      check_kernel_option "$kernel_config" "CONFIG_STRICT_KERNEL_RWX" "Strict kernel memory permissions"
      check_kernel_option "$kernel_config" "CONFIG_RANDOMIZE_BASE" "Kernel ASLR (KASLR)"
      check_kernel_option "$kernel_config" "CONFIG_HARDENED_USERCOPY" "Hardened usercopy"
      
      break
    fi
  done
  
  if [ "$config_found" = false ]; then
    print_check "SKIP" "Kernel config not available - cannot verify security features"
  fi
}

# Helper function to check kernel config option
check_kernel_option() {
  local config="$1"
  local option="$2"
  local description="$3"
  
  if echo "$config" | grep -q "^${option}=y"; then
    print_check "PASS" "${description} (${option}) is enabled"
  elif echo "$config" | grep -q "^${option}=m"; then
    print_check "INFO" "${description} (${option}) is compiled as module"
  elif echo "$config" | grep -q "^# ${option} is not set"; then
    print_check "FAIL" "${description} (${option}) is DISABLED" "MEDIUM"
  fi
}

# Function to run bootkit detection
check_bootkits() {
  print_section "Bootkit Detection"
  
  if [ ! -f "${SCRIPT_DIR}/detect_bootkit.py" ]; then
    print_check "SKIP" "Bootkit detection script not found"
    return
  fi
  
  # Check if we have a firmware baseline
  local baseline_path="${OUT_DIR}/baseline/firmware_baseline.json"
  if [ ! -f "$baseline_path" ]; then
    print_check "INFO" "No firmware baseline found - bootkit detection limited"
    print_check "INFO" "Run 'bash scripts/scan-bootkits.sh' to create baseline and perform full scan"
    return
  fi
  
  print_check "INFO" "Running bootkit detection against firmware baseline..."
  local scan_output="${LOG_DIR}/bootkit_scan_${TIMESTAMP}.json"
  
  if check_root; then
    "${PY}" "${SCRIPT_DIR}/detect_bootkit.py" -b "$baseline_path" --output "$scan_output" 2>&1 || true
    
    if [ -f "$scan_output" ]; then
      local risk_level=$(${PY} -c "import json; print(json.load(open('$scan_output')).get('risk_level', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
      
      case "$risk_level" in
        "CRITICAL")
          print_check "FAIL" "CRITICAL bootkit threat detected! See ${scan_output}" "CRITICAL"
          ;;
        "HIGH")
          print_check "FAIL" "HIGH risk bootkit indicators found - see ${scan_output}" "HIGH"
          ;;
        "MEDIUM")
          print_check "FAIL" "MEDIUM risk detected - see ${scan_output}" "MEDIUM"
          ;;
        "LOW")
          print_check "PASS" "LOW risk - system appears clean"
          ;;
        *)
          print_check "INFO" "Bootkit scan completed - risk: ${risk_level}"
          ;;
      esac
    else
      print_check "FAIL" "Bootkit detection failed to produce output" "LOW"
    fi
  else
    print_check "SKIP" "Bootkit detection requires root access"
  fi
}

# Function to check kernel module signatures
check_module_signatures() {
  print_section "Kernel Module Signature Check"
  
  local modules_dir="/lib/modules/$(uname -r)"
  if [ ! -d "$modules_dir" ]; then
    print_check "SKIP" "Kernel modules directory not found"
    return
  fi
  
  print_check "INFO" "Checking kernel modules in ${modules_dir}"
  
  # Sample check: find some modules and verify signatures
  local unsigned_count=0
  local signed_count=0
  local total_checked=0
  local max_check=20  # Only check first 20 modules for performance
  
  while IFS= read -r module && [ $total_checked -lt $max_check ]; do
    ((total_checked++))
    
    # Check if module has signature
    if modinfo "$module" 2>/dev/null | grep -q "^sig_id:"; then
      ((signed_count++))
    else
      ((unsigned_count++))
    fi
  done < <(find "$modules_dir" -name "*.ko*" -type f | head -n $max_check)
  
  if [ $total_checked -gt 0 ]; then
    print_check "INFO" "Checked ${total_checked} modules: ${signed_count} signed, ${unsigned_count} unsigned"
    
    if [ $unsigned_count -gt 0 ]; then
      local unsigned_pct=$((unsigned_count * 100 / total_checked))
      if [ $unsigned_pct -gt 50 ]; then
        print_check "FAIL" "${unsigned_pct}% of modules are unsigned - consider signing with PhoenixBoot MOK" "MEDIUM"
      else
        print_check "INFO" "${unsigned_pct}% of modules are unsigned"
      fi
    else
      print_check "PASS" "All checked modules are signed"
    fi
  fi
  
  # Check if PhoenixGuard MOK is enrolled
  if command -v mokutil &> /dev/null; then
    local mok_list="${LOG_DIR}/mok_list_${TIMESTAMP}.txt"
    mokutil --list-enrolled 2>/dev/null > "$mok_list" || true
    
    if grep -q "PhoenixGuard\|PGMOK" "$mok_list" 2>/dev/null; then
      print_check "PASS" "PhoenixGuard MOK certificate is enrolled"
    else
      print_check "INFO" "PhoenixGuard MOK not found - use './pf.py mok-flow' to enroll"
    fi
  fi
}

# Function to check for common attack vectors
check_attack_vectors() {
  print_section "Common Attack Vector Check"
  
  # Check for suspicious boot parameters
  if [ -f /proc/cmdline ]; then
    local cmdline=$(cat /proc/cmdline)
    print_check "INFO" "Current boot parameters: ${cmdline}"
    
    # Check for dangerous parameters
    if echo "$cmdline" | grep -qE "init=/bin/sh|init=/bin/bash|single|emergency"; then
      print_check "FAIL" "Dangerous boot parameters detected - system may have been compromised" "CRITICAL"
    else
      print_check "PASS" "No dangerous boot parameters detected"
    fi
    
    # Check for security-enhancing parameters
    if echo "$cmdline" | grep -q "lockdown"; then
      print_check "PASS" "Kernel lockdown parameter present in boot command line"
    fi
  fi
  
  # Check for rootkit indicators
  if command -v rkhunter &> /dev/null; then
    print_check "INFO" "rkhunter available - consider running full rootkit scan"
  fi
  
  # Check firmware files for modifications
  if [ -d /lib/firmware ]; then
    print_check "PASS" "Firmware directory accessible at /lib/firmware"
  fi
}

# Function to check firmware checksums against database
check_firmware_checksums() {
  print_section "Firmware Checksum Verification"
  
  # Check if firmware checksum tool is available
  if [ ! -f "${REPO_ROOT}/utils/firmware_checksum_db.py" ]; then
    print_check "SKIP" "Firmware checksum database tool not found"
    return
  fi
  
  print_check "INFO" "Firmware checksum database available"
  
  # Check for common firmware locations
  local firmware_locations=(
    "/sys/firmware/efi"
    "/lib/firmware"
    "/boot/efi/EFI"
  )
  
  local firmware_found=false
  for fw_path in "${firmware_locations[@]}"; do
    if [ -d "$fw_path" ]; then
      firmware_found=true
      print_check "INFO" "Firmware location: ${fw_path}"
    fi
  done
  
  if ! $firmware_found; then
    print_check "SKIP" "No firmware locations found"
    return
  fi
  
  # Note about firmware verification
  print_check "INFO" "Firmware checksum verification available via:"
  print_check "INFO" "  ${PY} ${REPO_ROOT}/utils/firmware_checksum_db.py --verify <firmware_file>"
}

# Function to analyze kernel hardening configuration
check_kernel_hardening() {
  print_section "Kernel Hardening Configuration Analysis"
  
  # Check if kernel hardening analyzer is available
  if [ ! -f "${REPO_ROOT}/utils/kernel_hardening_analyzer.py" ]; then
    print_check "SKIP" "Kernel hardening analyzer not found"
    return
  fi
  
  print_check "INFO" "Running kernel hardening analysis..."
  
  # Run the analyzer
  local analysis_output="${LOG_DIR}/kernel_hardening_${TIMESTAMP}.txt"
  local analysis_json="${LOG_DIR}/kernel_hardening_${TIMESTAMP}.json"
  
  "${PY}" "${REPO_ROOT}/utils/kernel_hardening_analyzer.py" --auto --format text \
    --output "${analysis_output}" 2>&1 || true
  
  "${PY}" "${REPO_ROOT}/utils/kernel_hardening_analyzer.py" --auto --format json \
    --output "${analysis_json}" 2>&1 || true
  
  if [ -f "${analysis_json}" ]; then
    # Parse JSON results
    local security_level=$(${PY} -c "import json; print(json.load(open('${analysis_json}')).get('security_level', 'UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
    local score=$(${PY} -c "import json; print(json.load(open('${analysis_json}')).get('score', 0))" 2>/dev/null || echo "0")
    local failed=$(${PY} -c "import json; print(json.load(open('${analysis_json}')).get('failed', 0))" 2>/dev/null || echo "0")
    
    print_check "INFO" "Kernel hardening score: ${score}/100 (${security_level})"
    
    if [ "$security_level" = "POOR" ]; then
      print_check "FAIL" "Kernel hardening is POOR - ${failed} critical configurations missing" "HIGH"
    elif [ "$security_level" = "ACCEPTABLE" ]; then
      print_check "FAIL" "Kernel hardening is ACCEPTABLE - improvements recommended" "MEDIUM"
    elif [ "$security_level" = "GOOD" ] || [ "$security_level" = "EXCELLENT" ]; then
      print_check "PASS" "Kernel hardening configuration is ${security_level}"
    else
      print_check "INFO" "Kernel hardening analysis completed - see ${analysis_output}"
    fi
    
    # Check for critical missing options
    local critical_missing=$(${PY} -c "
import json
data = json.load(open('${analysis_json}'))
critical = [f for f in data.get('findings', []) if not f['passed'] and f['severity'] == 'CRITICAL']
print(len(critical))
" 2>/dev/null || echo "0")
    
    if [ "$critical_missing" -gt 0 ]; then
      print_check "FAIL" "${critical_missing} CRITICAL kernel hardening options are missing" "CRITICAL"
      print_check "INFO" "Run './pf.py kernel-hardening-report' for detailed analysis"
    fi
    
    print_check "PASS" "Detailed kernel hardening report: ${analysis_output}"
  else
    print_check "FAIL" "Kernel hardening analysis failed to produce output" "LOW"
  fi
}

# Function to check if kexec-based remediation is possible
check_kexec_remediation() {
  print_section "Kernel Remediation Capabilities"
  
  if [ ! -f "${REPO_ROOT}/utils/kernel_config_remediation.py" ]; then
    print_check "SKIP" "Kernel remediation tool not found"
    return
  fi
  
  print_check "INFO" "Checking kexec availability for kernel remediation..."
  
  # Check kexec status
  local kexec_output="${LOG_DIR}/kexec_check_${TIMESTAMP}.txt"
  "${PY}" "${REPO_ROOT}/utils/kernel_config_remediation.py" --check-kexec > "${kexec_output}" 2>&1 || true
  
  if grep -q "✓ Available" "${kexec_output}"; then
    print_check "PASS" "kexec is available - kernel remediation possible via double-jump"
    
    # Check lockdown state
    if grep -q "confidentiality" "${kexec_output}"; then
      print_check "FAIL" "Kernel lockdown in confidentiality mode - blocks kexec" "MEDIUM"
      print_check "INFO" "Consider using integrity mode for kexec-based remediation"
    elif grep -q "integrity" "${kexec_output}"; then
      print_check "PASS" "Kernel lockdown in integrity mode - allows signed kexec"
    fi
  else
    print_check "FAIL" "kexec not available - kernel remediation requires traditional reboot" "LOW"
  fi
  
  print_check "INFO" "For kexec double-jump guide: ${PY} ${REPO_ROOT}/utils/kernel_config_remediation.py --kexec-guide"
}

# Function to provide security recommendations
provide_recommendations() {
  print_section "Security Recommendations"
  
  local recommendations=()
  
  # Analyze collected issues and provide recommendations
  if [ $CRITICAL_ISSUES -gt 0 ] || [ $HIGH_ISSUES -gt 0 ]; then
    recommendations+=("🔴 URGENT: Address critical and high-severity issues immediately")
  fi
  
  # Specific recommendations based on checks
  if ! command -v mokutil &> /dev/null; then
    recommendations+=("📦 Install mokutil: sudo apt install mokutil (Ubuntu/Debian)")
  fi
  
  if [ ! -f "${OUT_DIR}/baseline/firmware_baseline.json" ]; then
    recommendations+=("📊 Create firmware baseline: bash scripts/scan-bootkits.sh")
  fi
  
  recommendations+=("🔐 Generate or update SecureBoot keys: ./pf.py secure-keygen")
  recommendations+=("🔑 Set up PhoenixGuard MOK: ./pf.py mok-flow")
  recommendations+=("✍️  Sign kernel modules: PATH=/lib/modules/\$(uname -r) FORCE=1 ./pf.py os-kmod-sign")
  recommendations+=("🔍 Run full validation: ./pf.py verify")
  recommendations+=("💿 Create SecureBoot USB: ISO_PATH=/path/to.iso ./pf.py secureboot-create")
  
  for rec in "${recommendations[@]}"; do
    echo -e "  ${rec}"
  done
}

# Function to generate summary
generate_summary() {
  print_section "Security Assessment Summary"
  
  local total_issues=$((CRITICAL_ISSUES + HIGH_ISSUES + MEDIUM_ISSUES + LOW_ISSUES))
  
  echo -e "Passed Checks:    ${GREEN}${PASSED_CHECKS}${NC}"
  echo -e "Critical Issues:  ${RED}${CRITICAL_ISSUES}${NC}"
  echo -e "High Issues:      ${RED}${HIGH_ISSUES}${NC}"
  echo -e "Medium Issues:    ${YELLOW}${MEDIUM_ISSUES}${NC}"
  echo -e "Low Issues:       ${YELLOW}${LOW_ISSUES}${NC}"
  echo -e "Total Issues:     ${total_issues}"
  
  echo ""
  
  # Overall security rating
  if [ $CRITICAL_ISSUES -gt 0 ]; then
    echo -e "Overall Security: ${RED}${BOLD}CRITICAL - IMMEDIATE ACTION REQUIRED${NC}"
    SECURITY_LEVEL="CRITICAL"
  elif [ $HIGH_ISSUES -gt 0 ]; then
    echo -e "Overall Security: ${RED}${BOLD}HIGH RISK - ACTION REQUIRED${NC}"
    SECURITY_LEVEL="HIGH_RISK"
  elif [ $MEDIUM_ISSUES -gt 2 ]; then
    echo -e "Overall Security: ${YELLOW}${BOLD}MEDIUM RISK - IMPROVEMENTS NEEDED${NC}"
    SECURITY_LEVEL="MEDIUM_RISK"
  elif [ $total_issues -gt 0 ]; then
    echo -e "Overall Security: ${YELLOW}${BOLD}ACCEPTABLE - MINOR IMPROVEMENTS SUGGESTED${NC}"
    SECURITY_LEVEL="ACCEPTABLE"
  else
    echo -e "Overall Security: ${GREEN}${BOLD}GOOD - SYSTEM IS WELL HARDENED${NC}"
    SECURITY_LEVEL="GOOD"
  fi
  
  echo ""
  echo -e "Detailed report saved to: ${REPORT_FILE}"
  echo -e "JSON report saved to: ${JSON_REPORT}"
}

# Function to save JSON report
save_json_report() {
  cat > "$JSON_REPORT" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "kernel": "$(uname -r)",
  "security_level": "${SECURITY_LEVEL}",
  "checks": {
    "passed": ${PASSED_CHECKS},
    "critical_issues": ${CRITICAL_ISSUES},
    "high_issues": ${HIGH_ISSUES},
    "medium_issues": ${MEDIUM_ISSUES},
    "low_issues": ${LOW_ISSUES},
    "total_issues": $((CRITICAL_ISSUES + HIGH_ISSUES + MEDIUM_ISSUES + LOW_ISSUES))
  },
  "reports": {
    "text_report": "${REPORT_FILE}",
    "log_directory": "${LOG_DIR}"
  }
}
EOF
}

# Main execution
main() {
  echo -e "${BOLD}${BLUE}"
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                                                                ║"
  echo "║        PhoenixBoot Security Environment Check v1.0            ║"
  echo "║        Comprehensive Boot & System Security Analysis          ║"
  echo "║                                                                ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  
  print_check "INFO" "Starting security environment check at $(date)"
  print_check "INFO" "System: $(uname -a)"
  
  # Check if running as root (don't fail on non-root)
  check_root || true
  
  # Run all security checks (don't fail script on individual check failures)
  check_uefi_mode || true
  check_secure_boot || true
  check_efi_variables || true
  check_boot_integrity || true
  check_kernel_security || true
  check_kernel_hardening || true
  check_firmware_checksums || true
  check_kexec_remediation || true
  check_bootkits || true
  check_module_signatures || true
  check_attack_vectors || true
  
  # Provide recommendations
  provide_recommendations
  
  # Generate summary
  generate_summary
  
  # Save JSON report
  save_json_report
  
  print_check "INFO" "Security check completed at $(date)"
  
  # Copy output to report file
  echo "Report saved to ${REPORT_FILE}"
  
  # Exit with appropriate code
  if [ $CRITICAL_ISSUES -gt 0 ]; then
    exit 2
  elif [ $HIGH_ISSUES -gt 0 ]; then
    exit 1
  else
    exit 0
  fi
}

# Run main function and save output to report
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  # Script is being executed directly, not sourced
  main "$@" 2>&1 | tee "$REPORT_FILE"
fi
