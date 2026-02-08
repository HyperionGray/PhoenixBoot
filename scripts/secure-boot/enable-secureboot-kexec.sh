#!/usr/bin/env bash
# PhoenixBoot - Enable Secure Boot via Double Kexec Method (HOST)
#
# What this does (high level):
#   Phase 1 (current kernel): preflight + stage state + load alternate kernel, then kexec.
#   Phase 2 (alternate kernel): optional Secure Boot key enrollment + optional custom command, then kexec back.
#   Phase 3 (back on original kernel): cleanup and status summary.
#
# Safety notes:
# - Secure Boot enablement is inherently risky and firmware-specific. This script will NOT attempt
#   firmware patching. It can optionally enroll PhoenixBoot keys via standard UEFI variables using
#   efitools' efi-updatevar when the platform is in Setup Mode.
# - Use --dry-run for a safe walkthrough that performs no writes and no kexec.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_PATH}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

STATE_DIR_DEFAULT="/var/lib/phoenixboot/secureboot-kexec"
UNIT_PHASE2="phoenixboot-secureboot-kexec-phase2.service"
UNIT_PHASE3="phoenixboot-secureboot-kexec-phase3.service"

DRY_RUN=0
ASSUME_YES=0
PHASE="1" # 1|2|3|cleanup
STATE_DIR="$STATE_DIR_DEFAULT"
RETURN_MODE="auto" # auto|stay
ACTION="auto"      # auto|enroll_keys|run_cmd|none
ALT_KERNEL_VER=""
PHASE2_CMD=""

usage() {
  cat <<EOF
Usage:
  sudo $0 [--dry-run] [--yes] [--state-dir DIR] [--alt-kernel VER] [--action MODE] [--return-mode MODE] [--phase2-cmd 'CMD']
  sudo $0 --direct [--dry-run] [--yes]
  sudo $0 --cleanup [--state-dir DIR]

Internal (used by systemd, do not run manually unless you know why):
  sudo $0 --phase2 [--state-dir DIR]
  sudo $0 --phase3 [--state-dir DIR]

Options:
  --action=MODE                        # auto|enroll_keys|run_cmd|none (default: auto)
  --return-mode=MODE                   # auto|stay (default: auto)
  --phase2-cmd='CMD'                   # run custom command during Phase 2 (implies --action=run_cmd)
  --state-dir=DIR                      # override state directory (default: /var/lib/phoenixboot/secureboot-kexec)
  --alt-kernel=VER                     # kernel version to use for Phase 2 (auto: newest alternative)

Notes:
  - --dry-run never runs kexec and never writes firmware variables.
  - --direct skips kexec and only attempts key enrollment (Setup Mode required).
  - Key enrollment uses out/securevars/{PK,KEK,db}.auth via 'efi-updatevar' (efitools).
EOF
}

log()  { echo -e "${BLUE}[phoenixboot]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*" >&2; }
die()  { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY: $*"
    return 0
  fi
  eval "$@"
}

confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" = "1" ]; then
    return 0
  fi
  read -r -p "$prompt [y/N] " -n 1 REPLY
  echo
  [[ "${REPLY:-}" =~ ^[Yy]$ ]]
}

has_systemd() {
  command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
}

efi_var_byte() {
  local var="$1"
  local f
  f="$(ls "/sys/firmware/efi/efivars/${var}-"* 2>/dev/null | head -n 1 || true)"
  [ -n "$f" ] || return 1
  od -An -t u1 -j 4 -N 1 "$f" 2>/dev/null | tr -d ' '
}

secureboot_enabled() {
  local v
  v="$(efi_var_byte SecureBoot 2>/dev/null || true)"
  [ "$v" = "1" ]
}

setup_mode_enabled() {
  local v
  v="$(efi_var_byte SetupMode 2>/dev/null || true)"
  [ "$v" = "1" ]
}

write_state() {
  umask 077
  run "mkdir -p $(printf '%q' "$STATE_DIR")"

  local state_env="$STATE_DIR/state.env"
  local orig_cmdline_file="$STATE_DIR/orig_cmdline"
  local phase2_cmd_file="$STATE_DIR/phase2_cmd"

  local orig_kernel_ver
  orig_kernel_ver="$(uname -r)"
  local orig_vmlinuz="/boot/vmlinuz-${orig_kernel_ver}"
  local orig_initrd="/boot/initrd.img-${orig_kernel_ver}"

  [ -f "$orig_vmlinuz" ] || die "Missing current kernel image: $orig_vmlinuz"
  [ -f "$orig_initrd" ] || warn "Initrd not found (will still try): $orig_initrd"

  local alt_vmlinuz="/boot/vmlinuz-${ALT_KERNEL_VER}"
  local alt_initrd="/boot/initrd.img-${ALT_KERNEL_VER}"
  [ -f "$alt_vmlinuz" ] || die "Alternate kernel image not found: $alt_vmlinuz"
  [ -f "$alt_initrd" ] || die "Alternate initrd not found: $alt_initrd"

  local orig_cmdline
  orig_cmdline="$(cat /proc/cmdline)"

  {
    printf 'REPO_ROOT=%q\n' "$REPO_ROOT"
    printf 'SCRIPT_PATH=%q\n' "$SCRIPT_PATH"
    printf 'STATE_DIR=%q\n' "$STATE_DIR"
    printf 'ORIG_KERNEL_VER=%q\n' "$orig_kernel_ver"
    printf 'ORIG_VMLINUZ=%q\n' "$orig_vmlinuz"
    printf 'ORIG_INITRD=%q\n' "$orig_initrd"
    printf 'ALT_KERNEL_VER=%q\n' "$ALT_KERNEL_VER"
    printf 'ALT_VMLINUZ=%q\n' "$alt_vmlinuz"
    printf 'ALT_INITRD=%q\n' "$alt_initrd"
    printf 'RETURN_MODE=%q\n' "$RETURN_MODE"
    printf 'ACTION=%q\n' "$ACTION"
  } | run "tee $(printf '%q' "$state_env") >/dev/null"

  printf '%s\n' "$orig_cmdline" | run "tee $(printf '%q' "$orig_cmdline_file") >/dev/null"

  if [ -n "$PHASE2_CMD" ]; then
    printf '%s\n' "$PHASE2_CMD" | run "tee $(printf '%q' "$phase2_cmd_file") >/dev/null"
  else
    run "rm -f $(printf '%q' "$phase2_cmd_file")"
  fi
}

read_state() {
  local state_env="$STATE_DIR/state.env"
  [ -f "$state_env" ] || die "State file missing: $state_env (did Phase 1 run?)"
  # shellcheck disable=SC1090
  source "$state_env"
}

install_systemd_units() {
  [ "$DRY_RUN" = "1" ] && { warn "dry-run: skipping systemd unit install"; return 0; }
  has_systemd || { warn "systemd not detected; Phase 2 must be run manually after kexec"; return 0; }

  local phase2_unit="/etc/systemd/system/${UNIT_PHASE2}"
  local phase3_unit="/etc/systemd/system/${UNIT_PHASE3}"

  cat > "$phase2_unit" <<EOF
[Unit]
Description=PhoenixBoot SecureBoot double-kexec (Phase 2)
ConditionKernelCommandLine=phoenixboot.secureboot_kexec=phase2
After=local-fs.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} --phase2 --state-dir ${STATE_DIR}
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

  cat > "$phase3_unit" <<EOF
[Unit]
Description=PhoenixBoot SecureBoot double-kexec (Phase 3 cleanup)
ConditionKernelCommandLine=phoenixboot.secureboot_kexec=phase3
After=local-fs.target

[Service]
Type=oneshot
ExecStart=${SCRIPT_PATH} --phase3 --state-dir ${STATE_DIR}
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$UNIT_PHASE2" >/dev/null
  systemctl enable "$UNIT_PHASE3" >/dev/null
  ok "Installed systemd units: $UNIT_PHASE2, $UNIT_PHASE3"
}

cleanup_systemd_units() {
  [ "$DRY_RUN" = "1" ] && { warn "dry-run: skipping cleanup"; return 0; }
  if has_systemd; then
    systemctl disable "$UNIT_PHASE2" >/dev/null 2>&1 || true
    systemctl disable "$UNIT_PHASE3" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/${UNIT_PHASE2}" "/etc/systemd/system/${UNIT_PHASE3}" || true
    systemctl daemon-reload >/dev/null 2>&1 || true
  else
    rm -f "/etc/systemd/system/${UNIT_PHASE2}" "/etc/systemd/system/${UNIT_PHASE3}" 2>/dev/null || true
  fi
}

cleanup_all() {
  cleanup_systemd_units
  run "rm -rf $(printf '%q' "$STATE_DIR")"
  ok "Cleaned up: $STATE_DIR"
}

choose_alt_kernel() {
  local current_kernel
  current_kernel="$(uname -r)"

  if [ -n "$ALT_KERNEL_VER" ]; then
    return 0
  fi

  mapfile -t kernels < <(ls /boot/vmlinuz-* 2>/dev/null | sed 's|/boot/vmlinuz-||' | grep -v -- "$current_kernel" | sort -V -r || true)
  if [ ${#kernels[@]} -eq 0 ]; then
    if [ "$DRY_RUN" = "1" ]; then
      ALT_KERNEL_VER=""
      warn "dry-run: no alternate kernels found under /boot/vmlinuz-* (need at least 2 kernels installed for real kexec)"
      return 0
    fi
    die "No alternate kernels found under /boot/vmlinuz-* (need at least 2 kernels installed)"
  fi

  ALT_KERNEL_VER="${kernels[0]}"
}

detect_action_defaults() {
  if [ "$ACTION" != "auto" ]; then
    return 0
  fi

  if setup_mode_enabled && command -v efi-updatevar >/dev/null 2>&1 \
     && [ -f "${REPO_ROOT}/out/securevars/PK.auth" ] && [ -f "${REPO_ROOT}/out/securevars/KEK.auth" ] && [ -f "${REPO_ROOT}/out/securevars/db.auth" ]; then
    ACTION="enroll_keys"
    return 0
  fi

  if [ -n "$PHASE2_CMD" ]; then
    ACTION="run_cmd"
    return 0
  fi

  ACTION="none"
}

phase1() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║        PhoenixBoot - Secure Boot Enablement (Double Kexec)        ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
  echo

  if [ "$DRY_RUN" != "1" ] && [ "$EUID" -ne 0 ]; then
    die "This script must be run as root. Try: sudo $0"
  fi

  if [ ! -d /sys/firmware/efi ]; then
    if [ "$DRY_RUN" = "1" ]; then
      warn "dry-run: not a UEFI system here; continuing to show planned actions"
    else
      die "Not a UEFI system - Secure Boot not available"
    fi
  fi

  if secureboot_enabled; then
    ok "Secure Boot is already enabled; nothing to do."
    return 0
  fi

  echo -e "${YELLOW}⚠ WARNING: Advanced operation${NC}"
  echo "This can kexec between kernels and may interrupt network/SSH."
  echo "It can optionally enroll Secure Boot keys via UEFI variables (Setup Mode only)."
  echo
  echo -e "${BOLD}Prereqs:${NC}"
  echo "  - kexec-tools installed"
  echo "  - At least two kernels installed"
  echo "  - Backups of important data"
  echo

  if ! confirm "Continue?"; then
    die "Aborted."
  fi

  choose_alt_kernel
  detect_action_defaults

  log "Current kernel: $(uname -r)"
  log "Alternate kernel: ${ALT_KERNEL_VER:-<none found>}"

  if [ "$DRY_RUN" != "1" ]; then
    command -v kexec >/dev/null 2>&1 || die "kexec not found. Install: apt install kexec-tools"
  else
    command -v kexec >/dev/null 2>&1 || warn "dry-run: kexec not found (would require: apt install kexec-tools)"
  fi

  if [ -f /sys/kernel/security/lockdown ]; then
    log "Kernel lockdown: $(cat /sys/kernel/security/lockdown 2>/dev/null || true)"
  fi

  if [ "$ACTION" = "enroll_keys" ]; then
    log "Phase 2 action: enroll PhoenixBoot keys via efi-updatevar (out/securevars/*.auth)"
  elif [ "$ACTION" = "run_cmd" ]; then
    log "Phase 2 action: run custom command (--phase2-cmd)"
  else
    log "Phase 2 action: none (kexec round-trip only)"
  fi
  log "Return mode: $RETURN_MODE"
  echo

  if [ "$DRY_RUN" = "1" ]; then
    ok "dry-run: no changes made."
    echo "Would write state under: $STATE_DIR"
    echo "Would install systemd units (if available): $UNIT_PHASE2, $UNIT_PHASE3"
    if [ -n "$ALT_KERNEL_VER" ]; then
      echo "Would kexec to: /boot/vmlinuz-$ALT_KERNEL_VER (with phoenixboot.secureboot_kexec=phase2)"
    else
      echo "Would kexec to: <no alternate kernel found>"
    fi
    return 0
  fi

  if [ "$ASSUME_YES" != "1" ]; then
    if ! confirm "Proceed to stage state + arm systemd + kexec to alternate kernel now?"; then
      die "Aborted."
    fi
  fi

  write_state
  install_systemd_units

  # Load alternate kernel
  local alt_cmdline
  alt_cmdline="$(cat "$STATE_DIR/orig_cmdline") phoenixboot.secureboot_kexec=phase2 phoenixboot.state_dir=${STATE_DIR}"

  log "Loading alternate kernel for kexec..."
  read_state
  log "  vmlinuz: $ALT_VMLINUZ"
  log "  initrd:  $ALT_INITRD"
  log "  cmdline: $alt_cmdline"

  run "kexec -l $(printf '%q' "$ALT_VMLINUZ") --initrd=$(printf '%q' "$ALT_INITRD") --command-line=$(printf '%q' "$alt_cmdline")"

  ok "Kernel loaded."
  echo
  echo -e "${YELLOW}⚠ About to execute kexec${NC}"
  echo "If systemd units could not be installed, Phase 2 must be run manually after boot:"
  echo "  sudo ${SCRIPT_PATH} --phase2 --state-dir ${STATE_DIR}"
  echo

  if ! confirm "Execute kexec now?"; then
    die "Aborted before kexec."
  fi

  run "sync"
  run "kexec -e"
}

find_auth_files() {
  local base="${REPO_ROOT}"

  PK_AUTH=""
  KEK_AUTH=""
  DB_AUTH=""

  if [ -f "${base}/out/securevars/PK.auth" ] && [ -f "${base}/out/securevars/KEK.auth" ] && [ -f "${base}/out/securevars/db.auth" ]; then
    PK_AUTH="${base}/out/securevars/PK.auth"
    KEK_AUTH="${base}/out/securevars/KEK.auth"
    DB_AUTH="${base}/out/securevars/db.auth"
    return 0
  fi

  if [ -f "${base}/secureboot_certs/PK.auth" ] && [ -f "${base}/secureboot_certs/KEK.auth" ] && [ -f "${base}/secureboot_certs/db.auth" ]; then
    PK_AUTH="${base}/secureboot_certs/PK.auth"
    KEK_AUTH="${base}/secureboot_certs/KEK.auth"
    DB_AUTH="${base}/secureboot_certs/db.auth"
    return 0
  fi

  return 1
}

phase2_enroll_keys() {
  command -v efi-updatevar >/dev/null 2>&1 || { warn "efi-updatevar not found (install: apt install efitools)"; return 1; }

  if ! setup_mode_enabled; then
    warn "Setup Mode is NOT enabled; refusing to overwrite Secure Boot keys from OS."
    warn "If you intend to enroll custom keys, clear keys in BIOS/UEFI first (enter Setup Mode), then rerun."
    return 0
  fi

  if ! find_auth_files; then
    warn "Auth files not found. Generate them with:"
    warn "  ./pf.py secure-keygen"
    warn "  ./pf.py secure-make-auth"
    warn "Expected: out/securevars/PK.auth, KEK.auth, db.auth"
    return 1
  fi

  log "Enrolling keys via efi-updatevar (PK -> KEK -> db):"
  log "  PK:  $PK_AUTH"
  log "  KEK: $KEK_AUTH"
  log "  db:  $DB_AUTH"

  run "efi-updatevar -f $(printf '%q' "$PK_AUTH") PK"
  run "efi-updatevar -f $(printf '%q' "$KEK_AUTH") KEK"
  run "efi-updatevar -f $(printf '%q' "$DB_AUTH") db"

  ok "efi-updatevar completed (firmware may require reboot for Secure Boot to fully take effect)."
  return 0
}

phase2() {
  if [ "$DRY_RUN" = "1" ] && [ ! -f "$STATE_DIR/state.env" ]; then
    warn "dry-run: missing state file ($STATE_DIR/state.env); nothing to do."
    return 0
  fi
  read_state

  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}    PhoenixBoot - Phase 2 (Alternate Kernel)                        ${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
  echo
  log "Kernel: $(uname -r)"
  log "State dir: $STATE_DIR"
  echo

  if [ "$DRY_RUN" != "1" ] && [ "$EUID" -ne 0 ]; then
    die "Phase 2 must run as root."
  fi

  if [ ! -d /sys/firmware/efi ]; then
    warn "UEFI sysfs not present; Secure Boot vars may be inaccessible."
  fi

  if [ -c /dev/mem ]; then
    ok "/dev/mem present (permissive kernel access available)"
  else
    warn "/dev/mem not present in this kernel (CONFIG_DEVMEM=n)"
  fi

  if [ "$ACTION" = "enroll_keys" ]; then
    phase2_enroll_keys || true
  fi

  if [ "$ACTION" = "run_cmd" ]; then
    local cmd_file="$STATE_DIR/phase2_cmd"
    if [ -f "$cmd_file" ]; then
      local cmd
      cmd="$(cat "$cmd_file")"
      log "Running custom Phase 2 command:"
      echo "  $cmd"
      run "$cmd"
      ok "Phase 2 command finished."
    else
      warn "No Phase 2 command provided (missing $cmd_file)."
    fi
  fi

  if [ "$RETURN_MODE" = "stay" ]; then
    warn "RETURN_MODE=stay: leaving system in Phase 2 kernel. When ready, you can kexec back by running:"
    warn "  sudo ${SCRIPT_PATH} --phase3 --state-dir ${STATE_DIR}"
    return 0
  fi

  command -v kexec >/dev/null 2>&1 || die "kexec not found in Phase 2 (install kexec-tools)."

  local back_cmdline
  back_cmdline="$(cat "$STATE_DIR/orig_cmdline") phoenixboot.secureboot_kexec=phase3 phoenixboot.state_dir=${STATE_DIR}"

  log "Loading original kernel for return kexec..."
  log "  vmlinuz: $ORIG_VMLINUZ"
  log "  initrd:  $ORIG_INITRD"
  log "  cmdline: $back_cmdline"

  run "kexec -l $(printf '%q' "$ORIG_VMLINUZ") --initrd=$(printf '%q' "$ORIG_INITRD") --command-line=$(printf '%q' "$back_cmdline")"

  ok "Original kernel loaded."
  echo
  warn "About to kexec back to original kernel."
  run "sync"
  run "kexec -e"
}

phase3() {
  if [ "$DRY_RUN" = "1" ] && [ ! -f "$STATE_DIR/state.env" ]; then
    warn "dry-run: missing state file ($STATE_DIR/state.env); nothing to clean up."
    return 0
  fi
  read_state

  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}    PhoenixBoot - Phase 3 (Cleanup + Summary)                       ${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
  echo
  log "Kernel: $(uname -r)"
  echo

  if [ -d /sys/firmware/efi ]; then
    local sb sm
    sb="$(efi_var_byte SecureBoot 2>/dev/null || echo '?')"
    sm="$(efi_var_byte SetupMode 2>/dev/null || echo '?')"
    log "UEFI vars: SecureBoot=$sb SetupMode=$sm"
  else
    warn "UEFI sysfs not present; cannot read SecureBoot/SetupMode."
  fi

  echo
  echo "Next steps:"
  echo "  - If you enrolled keys, you may still need to enable Secure Boot in BIOS/UEFI, then reboot."
  echo "  - Verify anytime with: ./pf.py secureboot-check"
  echo

  cleanup_all
}

direct_enable() {
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}    PhoenixBoot - Direct Secure Boot Key Enrollment (No kexec)      ${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════════${NC}"
  echo

  if [ "$DRY_RUN" != "1" ] && [ "$EUID" -ne 0 ]; then
    die "This mode must be run as root. Try: sudo $0 --direct"
  fi

  if [ ! -d /sys/firmware/efi ]; then
    if [ "$DRY_RUN" = "1" ]; then
      warn "dry-run: not a UEFI system here; skipping."
      return 0
    fi
    die "Not a UEFI system - Secure Boot not available"
  fi

  if secureboot_enabled; then
    ok "Secure Boot is already enabled; nothing to do."
    return 0
  fi

  ACTION="enroll_keys"
  phase2_enroll_keys
  echo
  echo "Next steps:"
  echo "  - You may still need to enable Secure Boot in BIOS/UEFI, then reboot."
  echo "  - Verify anytime with: ./pf.py secureboot-check"
}

main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --dry-run) DRY_RUN=1; ASSUME_YES=1; shift ;;
      -y|--yes) ASSUME_YES=1; shift ;;
      --direct) PHASE="direct"; shift ;;
      --alt-kernel)
        if [ $# -lt 2 ]; then
          die "--alt-kernel requires a kernel version"
        fi
        ALT_KERNEL_VER="${2:-}"
        shift 2
        ;;
      --alt-kernel=*)
        ALT_KERNEL_VER="${1#*=}"
        shift
        ;;
      --action)
        if [ $# -lt 2 ]; then
          die "--action requires a value"
        fi
        ACTION="${2:-}"
        shift 2
        ;;
      --action=*)
        ACTION="${1#*=}"
        shift
        ;;
      --state-dir)
        if [ $# -lt 2 ]; then
          die "--state-dir requires a directory path"
        fi
        STATE_DIR="${2:-}"
        shift 2
        ;;
      --state-dir=*)
        STATE_DIR="${1#*=}"
        shift
        ;;
      --return-mode)
        if [ $# -lt 2 ]; then
          die "--return-mode requires a value"
        fi
        RETURN_MODE="${2:-}"
        shift 2
        ;;
      --return-mode=*)
        RETURN_MODE="${1#*=}"
        shift
        ;;
      --phase2-cmd)
        if [ $# -lt 2 ]; then
          die "--phase2-cmd requires an argument"
        fi
        PHASE2_CMD="${2:-}"
        shift 2
        ;;
      --phase2-cmd=*)
        PHASE2_CMD="${1#*=}"
        shift
        ;;
      --phase2) PHASE="2"; shift ;;
      --phase3) PHASE="3"; shift ;;
      --cleanup) PHASE="cleanup"; shift ;;
      *) die "Unknown arg: $1 (try --help)" ;;
    esac
  done

  case "$PHASE" in
    1) phase1 ;;
    2) phase2 ;;
    3) phase3 ;;
    direct) direct_enable ;;
    cleanup) cleanup_all ;;
    *) die "Invalid phase: $PHASE" ;;
  esac
}

main "$@"
