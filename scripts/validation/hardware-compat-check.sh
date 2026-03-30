#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

REPORT_DIR="${REPO_ROOT}/out/reports"
TMP_DIR="${REPO_ROOT}/out/tmp"
mkdir -p "${REPORT_DIR}" "${TMP_DIR}"

if [ -x "/home/punk/.venv/bin/python3" ]; then
  PYTHON_BIN="/home/punk/.venv/bin/python3"
else
  PYTHON_BIN="python3"
fi

usage() {
  cat <<'EOF'
Usage: hardware-compat-check.sh [options]

Options:
  --strict               Return exit code 1 when warnings exist
  --text-out <path>      Write text report to custom path
  --json-out <path>      Write JSON report to custom path
  --help                 Show this help
EOF
}

STRICT=0
TEXT_OUT=""
JSON_OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --strict)
      STRICT=1
      ;;
    --text-out)
      shift
      [ "$#" -gt 0 ] || { echo "ERROR: --text-out requires a path" >&2; exit 1; }
      TEXT_OUT="$1"
      ;;
    --json-out)
      shift
      [ "$#" -gt 0 ] || { echo "ERROR: --json-out requires a path" >&2; exit 1; }
      JSON_OUT="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

TS="$(date +%Y%m%d_%H%M%S)"
if [ -z "${TEXT_OUT}" ]; then
  TEXT_OUT="${REPORT_DIR}/hardware_compatibility_${TS}.txt"
fi
if [ -z "${JSON_OUT}" ]; then
  JSON_OUT="${REPORT_DIR}/hardware_compatibility_${TS}.json"
fi

RESULTS_TSV="$(mktemp "${TMP_DIR}/hardware_compat_results.XXXXXX.tsv")"
trap 'rm -f "${RESULTS_TSV}"' EXIT

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

record_check() {
  local status="$1"
  local category="$2"
  local item="$3"
  local detail="$4"
  detail="${detail//$'\t'/ }"
  detail="${detail//$'\n'/ }"

  case "${status}" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1));;
    WARN) WARN_COUNT=$((WARN_COUNT + 1));;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1));;
    *)
      echo "ERROR: invalid status: ${status}" >&2
      exit 1
      ;;
  esac

  printf '%s\t%s\t%s\t%s\n' "${status}" "${category}" "${item}" "${detail}" >> "${RESULTS_TSV}"
  printf '[%s] %-18s %-24s %s\n' "${status}" "${category}" "${item}" "${detail}"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

cmd_path_or_missing() {
  if have_cmd "$1"; then
    command -v "$1"
  else
    printf 'missing'
  fi
}

check_host_basics() {
  local os_name arch_name
  os_name="$(uname -s 2>/dev/null || echo unknown)"
  arch_name="$(uname -m 2>/dev/null || echo unknown)"

  if [ "${os_name}" = "Linux" ]; then
    record_check "PASS" "host" "operating_system" "Linux detected"
  else
    record_check "FAIL" "host" "operating_system" "Expected Linux, found ${os_name}"
  fi

  case "${arch_name}" in
    x86_64|aarch64)
      record_check "PASS" "host" "architecture" "Supported architecture: ${arch_name}"
      ;;
    *)
      record_check "WARN" "host" "architecture" "Architecture not widely tested: ${arch_name}"
      ;;
  esac

  if [ -d /sys/firmware/efi ]; then
    record_check "PASS" "host" "uefi_runtime" "UEFI runtime directory is present"
  else
    record_check "FAIL" "host" "uefi_runtime" "System is not running in UEFI mode"
  fi
}

check_secureboot_tooling() {
  local critical_tools optional_tools tool
  critical_tools=(openssl mokutil efibootmgr)
  optional_tools=(cert-to-efi-sig-list sign-efi-sig-list sbverify sbsign efi-readvar efi-updatevar)

  for tool in "${critical_tools[@]}"; do
    if have_cmd "${tool}"; then
      record_check "PASS" "secureboot" "${tool}" "Available at $(cmd_path_or_missing "${tool}")"
    else
      record_check "FAIL" "secureboot" "${tool}" "Missing required tool for Secure Boot workflows"
    fi
  done

  for tool in "${optional_tools[@]}"; do
    if have_cmd "${tool}"; then
      record_check "PASS" "secureboot" "${tool}" "Available at $(cmd_path_or_missing "${tool}")"
    else
      record_check "WARN" "secureboot" "${tool}" "Optional tool missing; some workflows may be limited"
    fi
  done
}

check_esp_state() {
  local mount_info fs_type
  if [ -d /boot/efi ]; then
    record_check "PASS" "storage" "esp_directory" "/boot/efi exists"
  else
    record_check "FAIL" "storage" "esp_directory" "/boot/efi is missing"
    return
  fi

  if have_cmd findmnt; then
    mount_info="$(findmnt -n /boot/efi 2>/dev/null || true)"
    if [ -n "${mount_info}" ]; then
      fs_type="$(findmnt -n -o FSTYPE /boot/efi 2>/dev/null || true)"
      case "${fs_type}" in
        vfat|fat|msdos)
          record_check "PASS" "storage" "esp_mount" "Mounted with filesystem type ${fs_type}"
          ;;
        *)
          if [ -n "${fs_type}" ]; then
            record_check "WARN" "storage" "esp_mount" "Mounted with unusual filesystem type ${fs_type}"
          else
            record_check "WARN" "storage" "esp_mount" "Mounted, but filesystem type was not detected"
          fi
          ;;
      esac
    else
      record_check "WARN" "storage" "esp_mount" "/boot/efi is not mounted"
    fi
  else
    record_check "WARN" "storage" "esp_mount" "findmnt not available; mount state unknown"
  fi
}

check_qemu_support() {
  local ovmf_code_paths ovmf_vars_paths path_found
  if have_cmd qemu-system-x86_64; then
    record_check "PASS" "qemu" "qemu_system" "qemu-system-x86_64 available"
  else
    record_check "WARN" "qemu" "qemu_system" "qemu-system-x86_64 missing"
  fi

  if have_cmd mcopy; then
    record_check "PASS" "qemu" "mtools" "mcopy available for ESP image operations"
  else
    record_check "WARN" "qemu" "mtools" "mcopy missing; QEMU test packaging may fail"
  fi

  ovmf_code_paths=(
    /usr/share/OVMF/OVMF_CODE.fd
    /usr/share/edk2/ovmf/OVMF_CODE.fd
    /usr/share/edk2/x64/OVMF_CODE.fd
  )
  ovmf_vars_paths=(
    /usr/share/OVMF/OVMF_VARS.fd
    /usr/share/edk2/ovmf/OVMF_VARS.fd
    /usr/share/edk2/x64/OVMF_VARS.fd
  )

  path_found=0
  for path in "${ovmf_code_paths[@]}"; do
    if [ -f "${path}" ]; then
      record_check "PASS" "qemu" "ovmf_code" "Found ${path}"
      path_found=1
      break
    fi
  done
  if [ "${path_found}" -eq 0 ]; then
    record_check "WARN" "qemu" "ovmf_code" "OVMF_CODE.fd not found in common locations"
  fi

  path_found=0
  for path in "${ovmf_vars_paths[@]}"; do
    if [ -f "${path}" ]; then
      record_check "PASS" "qemu" "ovmf_vars" "Found ${path}"
      path_found=1
      break
    fi
  done
  if [ "${path_found}" -eq 0 ]; then
    record_check "WARN" "qemu" "ovmf_vars" "OVMF_VARS.fd not found in common locations"
  fi
}

check_virtualization_support() {
  if grep -Eq "vmx|svm" /proc/cpuinfo 2>/dev/null; then
    record_check "PASS" "virtualization" "cpu_flags" "Hardware virtualization CPU flags detected"
  else
    record_check "WARN" "virtualization" "cpu_flags" "No vmx/svm flags detected"
  fi

  if [ -e /dev/kvm ]; then
    record_check "PASS" "virtualization" "kvm_device" "/dev/kvm exists"
  else
    record_check "WARN" "virtualization" "kvm_device" "/dev/kvm missing; acceleration unavailable"
  fi
}

check_module_signing_support() {
  local uname_r sign_file
  uname_r="$(uname -r)"
  sign_file="/usr/src/linux-headers-${uname_r}/scripts/sign-file"

  if [ -f "${sign_file}" ]; then
    record_check "PASS" "kmod" "sign_file" "Kernel sign-file helper found"
  else
    record_check "WARN" "kmod" "sign_file" "Kernel sign-file helper not found at ${sign_file}"
  fi

  if [ -f "${REPO_ROOT}/out/keys/mok/PGMOK.crt" ] || [ -f "${REPO_ROOT}/out/keys/PGMOK.crt" ]; then
    record_check "PASS" "kmod" "mok_cert" "MOK certificate found in out/keys"
  else
    record_check "WARN" "kmod" "mok_cert" "MOK certificate not found (run ./pf.py secure-mok-new)"
  fi
}

check_recovery_tools() {
  if have_cmd flashrom; then
    record_check "PASS" "recovery" "flashrom" "flashrom available for firmware operations"
  else
    record_check "WARN" "recovery" "flashrom" "flashrom not installed (hardware recovery limited)"
  fi

  if have_cmd chipsec_main; then
    record_check "PASS" "recovery" "chipsec" "chipsec_main available"
  else
    record_check "WARN" "recovery" "chipsec" "chipsec not installed (deep chipset checks unavailable)"
  fi
}

generate_text_report() {
  {
    echo "PhoenixBoot Hardware Compatibility Report"
    echo "Generated at: $(date -Iseconds)"
    echo "Host: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo
    printf '%-5s | %-14s | %-24s | %s\n' "STAT" "CATEGORY" "ITEM" "DETAIL"
    printf '%s\n' "----------------------------------------------------------------------"
    while IFS=$'\t' read -r status category item detail; do
      printf '%-5s | %-14s | %-24s | %s\n' "${status}" "${category}" "${item}" "${detail}"
    done < "${RESULTS_TSV}"
    echo
    echo "Summary:"
    echo "  pass: ${PASS_COUNT}"
    echo "  warn: ${WARN_COUNT}"
    echo "  fail: ${FAIL_COUNT}"
  } > "${TEXT_OUT}"
}

generate_json_report() {
  "${PYTHON_BIN}" - "${RESULTS_TSV}" "${JSON_OUT}" "${PASS_COUNT}" "${WARN_COUNT}" "${FAIL_COUNT}" "${STRICT}" <<'PY'
import json
import socket
import sys
from datetime import datetime, timezone

results_tsv, json_out, pass_count, warn_count, fail_count, strict_mode = sys.argv[1:7]

checks = []
with open(results_tsv, "r", encoding="utf-8") as f:
    for line in f:
        parts = line.rstrip("\n").split("\t")
        if len(parts) != 4:
            continue
        status, category, item, detail = parts
        checks.append(
            {
                "status": status,
                "category": category,
                "item": item,
                "detail": detail,
            }
        )

fail_count_i = int(fail_count)
warn_count_i = int(warn_count)
if fail_count_i > 0:
    overall = "incompatible"
elif warn_count_i > 0:
    overall = "compatible_with_warnings"
else:
    overall = "compatible"

payload = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "host": socket.gethostname(),
    "strict_mode": strict_mode == "1",
    "overall_status": overall,
    "summary": {
        "pass": int(pass_count),
        "warn": warn_count_i,
        "fail": fail_count_i,
        "total": int(pass_count) + warn_count_i + fail_count_i,
    },
    "checks": checks,
}

with open(json_out, "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2, sort_keys=True)
PY
}

echo "Running PhoenixBoot hardware compatibility checks..."
check_host_basics
check_secureboot_tooling
check_esp_state
check_qemu_support
check_virtualization_support
check_module_signing_support
check_recovery_tools

generate_text_report
generate_json_report

echo
echo "Compatibility check completed."
echo "Text report: ${TEXT_OUT}"
echo "JSON report: ${JSON_OUT}"
echo "Summary: pass=${PASS_COUNT}, warn=${WARN_COUNT}, fail=${FAIL_COUNT}"

if [ "${FAIL_COUNT}" -gt 0 ]; then
  exit 2
fi
if [ "${STRICT}" -eq 1 ] && [ "${WARN_COUNT}" -gt 0 ]; then
  exit 1
fi
exit 0
