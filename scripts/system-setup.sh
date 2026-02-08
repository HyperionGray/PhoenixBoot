#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

if [ -f scripts/lib/common.sh ]; then
  # shellcheck disable=SC1091
  source scripts/lib/common.sh
else
  log()  { printf '%s\n' "$*"; }
  info() { printf 'ℹ☠  %s\n' "$*"; }
  ok()   { printf '☠ %s\n' "$*"; }
  err()  { printf '☠ %s\n' "$*" >&2; }
  die()  { err "$*"; exit 1; }
fi

ACTION=${1:-}
shift || true

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die "sudo not found; re-run as root or install sudo"
  SUDO="sudo"
fi

case "${ACTION}" in
  update)
    info "Updating apt package lists..."
    ${SUDO} apt-get update
    ;;
  upgrade)
    info "Upgrading system packages..."
    ${SUDO} apt-get update
    ${SUDO} apt-get upgrade -y
    ;;
  install-base)
    info "Installing base PhoenixBoot dependencies..."
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y \
      bash coreutils util-linux \
      python3 python3-venv python3-pip \
      qemu-system-x86 ovmf mtools genisoimage \
      dosfstools sbsigntool efitools \
      efibootmgr mokutil openssl \
      parted
    ok "Base dependencies installed"
    ;;
  setup-venv)
    VENV_PATH_ARG=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --venv-path|-p)
          shift || die "Missing value for $1"
          VENV_PATH_ARG="$1"
          ;;
        --help|-h)
          die "Usage: $0 setup-venv [--venv-path PATH]"
          ;;
        *)
          die "Unknown option for setup-venv: $1"
          ;;
      esac
      shift || true
    done

    VENV_PATH="${VENV_PATH_ARG:-"${HOME}/.venv"}"
    info "Creating venv at ${VENV_PATH}..."
    python3 -m venv "${VENV_PATH}"
    "${VENV_PATH}/bin/pip" install -U pip
    if [ -f requirements.txt ]; then
      "${VENV_PATH}/bin/pip" install -r requirements.txt
    fi
    ok "Venv ready: source ${VENV_PATH}/bin/activate"
    ;;
  *)
    die "Usage: $0 {update|upgrade|install-base|setup-venv [--venv-path PATH]}"
    ;;
esac
