#!/usr/bin/env bash
# PhoenixBoot - Enable Secure Boot via double kexec workflow framework
#
# This script implements workflow orchestration only. The actual Secure Boot
# flip in phase 2 remains hardware-specific and should be performed with
# vendor tooling or firmware setup screens.

set -euo pipefail

STATE_DIR="${PHOENIXBOOT_STATE_DIR:-/var/lib/phoenixboot/secureboot-kexec}"
STATE_FILE="${STATE_DIR}/phase-state.env"
PHASE2_RUNNER="${STATE_DIR}/phase2-runner.sh"
PHASE2_HOOK="${STATE_DIR}/phase2-enable-hook.sh"

ASSUME_YES="${PHOENIXBOOT_ASSUME_YES:-0}"
EXECUTE_FIRST_KEXEC="${PHOENIXBOOT_EXECUTE_KEXEC:-0}"
AUTO_RETURN_KEXEC="${PHOENIXBOOT_AUTO_RETURN:-0}"

SCRIPT_REAL_PATH=""
if command -v readlink >/dev/null 2>&1; then
    SCRIPT_REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
fi
if [ -z "${SCRIPT_REAL_PATH}" ] && command -v realpath >/dev/null 2>&1; then
    SCRIPT_REAL_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || true)"
fi
if [ -z "${SCRIPT_REAL_PATH}" ]; then
    SCRIPT_REAL_PATH="${BASH_SOURCE[0]}"
fi

print_header() {
    echo "===================================================================="
    echo "PhoenixBoot Secure Boot Double Kexec Framework"
    echo "===================================================================="
    echo
}

prompt_confirm() {
    local prompt="$1"

    if [ "${ASSUME_YES}" = "1" ]; then
        echo "${prompt} [auto-yes]"
        return 0
    fi

    read -r -p "${prompt} [y/N] " reply
    [[ "${reply}" =~ ^[Yy]$ ]]
}

require_root() {
    if [ "${EUID}" -ne 0 ]; then
        echo "ERROR: This command must be run as root."
        echo "Run: sudo $0"
        exit 1
    fi
}

require_uefi() {
    if [ ! -d /sys/firmware/efi ]; then
        echo "ERROR: This host is not booted in UEFI mode."
        exit 1
    fi
}

check_secureboot_enabled() {
    local sb_file
    for sb_file in /sys/firmware/efi/efivars/SecureBoot-*; do
        [ -e "${sb_file}" ] || continue
        local sb_status
        sb_status="$(od -An -t u1 -j 4 -N 1 "${sb_file}" 2>/dev/null | tr -d ' ')"
        [ "${sb_status}" = "1" ] && return 0
    done

    if command -v mokutil >/dev/null 2>&1; then
        mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled" && return 0
    fi

    return 1
}

require_command() {
    local name="$1"
    local hint="$2"
    if ! command -v "${name}" >/dev/null 2>&1; then
        echo "ERROR: '${name}' is required."
        echo "Install hint: ${hint}"
        exit 1
    fi
}

kernel_assets_exist() {
    local version="$1"
    local vmlinuz="/boot/vmlinuz-${version}"
    local initrd="/boot/initrd.img-${version}"

    if [ ! -f "${vmlinuz}" ]; then
        echo "ERROR: Missing kernel image: ${vmlinuz}"
        return 1
    fi
    if [ ! -f "${initrd}" ]; then
        echo "ERROR: Missing initrd image: ${initrd}"
        return 1
    fi
    return 0
}

collect_alternate_kernel() {
    local current="$1"
    local kernel_path

    for kernel_path in /boot/vmlinuz-*; do
        [ -e "${kernel_path}" ] || continue
        local version
        version="$(basename "${kernel_path}" | sed 's/^vmlinuz-//')"
        if [ "${version}" != "${current}" ]; then
            echo "${version}"
            return 0
        fi
    done

    return 1
}

write_state_file() {
    local current_kernel="$1"
    local alternate_kernel="$2"
    local return_kernel="$3"
    local command_line="$4"

    mkdir -p "${STATE_DIR}"
    chmod 700 "${STATE_DIR}"

    {
        printf "PHASE=%q\n" "phase1-loaded"
        printf "CREATED_AT=%q\n" "$(date -Is)"
        printf "CURRENT_KERNEL=%q\n" "${current_kernel}"
        printf "ALTERNATE_KERNEL=%q\n" "${alternate_kernel}"
        printf "RETURN_KERNEL=%q\n" "${return_kernel}"
        printf "RETURN_CMDLINE=%q\n" "${command_line}"
    } > "${STATE_FILE}"
    chmod 600 "${STATE_FILE}"
}

write_phase2_runner() {
    local script_path_escaped
    script_path_escaped="$(printf '%q' "${SCRIPT_REAL_PATH}")"

    cat > "${PHASE2_RUNNER}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec ${script_path_escaped} --phase2
EOF
    chmod 700 "${PHASE2_RUNNER}"
}

cleanup_state() {
    rm -f "${STATE_FILE}" "${PHASE2_RUNNER}"
}

print_phase2_instructions() {
    cat <<EOF

Phase 2 handoff material created:
  State file:   ${STATE_FILE}
  Runner:       ${PHASE2_RUNNER}

After the first kexec boots the alternate kernel:
  1. Perform hardware-specific Secure Boot enablement
     (or enter firmware setup and enable Secure Boot there).
  2. Run: sudo ${PHASE2_RUNNER}
  3. That phase-2 step will load the return kernel via kexec and
     can optionally execute the return kexec immediately.

Optional phase-2 hook:
  ${PHASE2_HOOK}
If present and executable, it is run before loading the return kernel.
EOF
}

run_phase1() {
    print_header
    require_root
    require_uefi

    if check_secureboot_enabled; then
        echo "Secure Boot is already enabled. No action needed."
        exit 0
    fi

    echo "This workflow will:"
    echo "  1) kexec into an alternate kernel (phase 2)"
    echo "  2) let you perform Secure Boot enablement actions"
    echo "  3) kexec back to the original kernel version"
    echo

    if ! prompt_confirm "Continue with phase 1 preparation?"; then
        echo "Aborted."
        exit 1
    fi

    require_command kexec "apt install kexec-tools"
    require_command efibootmgr "apt install efibootmgr"

    local current_kernel
    current_kernel="$(uname -r)"
    local alternate_kernel
    alternate_kernel="$(collect_alternate_kernel "${current_kernel}" || true)"

    if [ -z "${alternate_kernel}" ]; then
        echo "ERROR: No alternate kernel found under /boot/vmlinuz-*."
        echo "Install a second kernel before using double kexec."
        exit 1
    fi

    local return_kernel="${current_kernel}"
    local current_cmdline
    current_cmdline="$(< /proc/cmdline)"

    echo "Current kernel:   ${current_kernel}"
    echo "Alternate kernel: ${alternate_kernel}"
    echo "Return kernel:    ${return_kernel}"
    echo

    kernel_assets_exist "${alternate_kernel}"
    kernel_assets_exist "${return_kernel}"

    write_state_file "${current_kernel}" "${alternate_kernel}" "${return_kernel}" "${current_cmdline}"
    write_phase2_runner
    print_phase2_instructions

    local alt_vmlinuz="/boot/vmlinuz-${alternate_kernel}"
    local alt_initrd="/boot/initrd.img-${alternate_kernel}"

    echo
    echo "Loading alternate kernel with kexec -l ..."
    kexec -l "${alt_vmlinuz}" --initrd="${alt_initrd}" --command-line="${current_cmdline}"
    echo "Alternate kernel loaded."

    if [ "${EXECUTE_FIRST_KEXEC}" = "1" ] || prompt_confirm "Execute first kexec now?"; then
        echo "Executing first kexec (switching to alternate kernel)."
        exec kexec -e
    fi

    cat <<EOF

First kexec was not executed automatically.
Run when ready:
  sudo kexec -e

Then in the alternate kernel run:
  sudo ${PHASE2_RUNNER}
EOF
}

run_phase2_hook_if_present() {
    if [ -x "${PHASE2_HOOK}" ]; then
        echo "Running phase-2 hook: ${PHASE2_HOOK}"
        "${PHASE2_HOOK}"
    else
        echo "No phase-2 hook detected. Proceeding with manual workflow."
    fi
}

run_phase2() {
    print_header
    require_root
    require_uefi

    if [ ! -f "${STATE_FILE}" ]; then
        echo "ERROR: No phase state found at ${STATE_FILE}"
        echo "Run phase 1 first."
        exit 1
    fi

    # shellcheck disable=SC1090
    . "${STATE_FILE}"

    : "${ALTERNATE_KERNEL:?missing ALTERNATE_KERNEL in state file}"
    : "${RETURN_KERNEL:?missing RETURN_KERNEL in state file}"
    : "${RETURN_CMDLINE:?missing RETURN_CMDLINE in state file}"

    local running_kernel
    running_kernel="$(uname -r)"
    echo "Running kernel:   ${running_kernel}"
    echo "Expected phase-2: ${ALTERNATE_KERNEL}"
    echo "Return kernel:    ${RETURN_KERNEL}"
    echo

    if [ "${running_kernel}" != "${ALTERNATE_KERNEL}" ]; then
        echo "WARNING: You are not running the recorded alternate kernel."
        echo "The return kexec can still be loaded, but validate your state first."
        echo
    fi

    run_phase2_hook_if_present

    if check_secureboot_enabled; then
        echo "Secure Boot reports ENABLED before return kexec."
    else
        echo "Secure Boot still appears DISABLED."
        echo "You may continue (for example, if a firmware reboot step is still needed)."
    fi

    if ! prompt_confirm "Load return kernel now?"; then
        echo "Phase 2 stopped without loading return kernel."
        exit 1
    fi

    kernel_assets_exist "${RETURN_KERNEL}"
    local ret_vmlinuz="/boot/vmlinuz-${RETURN_KERNEL}"
    local ret_initrd="/boot/initrd.img-${RETURN_KERNEL}"

    echo "Loading return kernel with kexec -l ..."
    kexec -l "${ret_vmlinuz}" --initrd="${ret_initrd}" --command-line="${RETURN_CMDLINE}"
    echo "Return kernel loaded."

    if [ "${AUTO_RETURN_KEXEC}" = "1" ] || prompt_confirm "Execute return kexec now?"; then
        echo "Cleaning phase state before final kexec."
        cleanup_state
        echo "Executing return kexec."
        exec kexec -e
    fi

    cat <<EOF

Return kernel is loaded but not executed.
To switch now:
  sudo kexec -e

After successful return, cleanup stale state:
  sudo ${SCRIPT_REAL_PATH} --cleanup-state
EOF
}

case "${1:-}" in
    --phase2)
        run_phase2
        ;;
    --cleanup-state)
        require_root
        cleanup_state
        echo "Cleaned phase state files under ${STATE_DIR}."
        ;;
    "")
        run_phase1
        ;;
    *)
        echo "Usage:"
        echo "  $0                # Run phase 1"
        echo "  $0 --phase2       # Complete phase 2 and prepare return kexec"
        echo "  $0 --cleanup-state"
        exit 1
        ;;
esac
