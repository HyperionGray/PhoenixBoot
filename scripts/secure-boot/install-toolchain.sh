#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."

DEBIAN_PKGS=(sbsigntool mokutil openssl util-linux)
DNF_PKGS=(mokutil openssl util-linux sbsigntool)
PACMAN_PKGS=(sbsigntool mokutil openssl util-linux)

NO_UPDATE=0

usage() {
  cat <<'USAGE'
Usage: install-toolchain.sh [--no-update]

Installs the SecureBoot helper toolchain (sbsigntool, mokutil, openssl).

Options:
  --no-update  skip `apt update` (only applies to apt-based systems)
  -h, --help   show this message
USAGE
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-update)
      NO_UPDATE=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

install_apt() {
  [ "$NO_UPDATE" -eq 1 ] || sudo apt update
  sudo apt install -y "${DEBIAN_PKGS[@]}"
}

install_dnf() {
  sudo dnf install -y "${DNF_PKGS[@]}"
}

install_pacman() {
  sudo pacman -Syu --needed "${PACMAN_PKGS[@]}"
}

if command -v apt >/dev/null 2>&1; then
  echo "Installing SecureBoot toolchain via apt"
  install_apt
  exit 0
fi

if command -v dnf >/dev/null 2>&1; then
  echo "Installing SecureBoot toolchain via dnf"
  install_dnf
  exit 0
fi

if command -v pacman >/dev/null 2>&1; then
  echo "Installing SecureBoot toolchain via pacman"
  install_pacman
  exit 0
fi

cat <<'MSG'
No supported package manager detected. Please install the following packages manually:
  - sbsigntool (provides cert-to-efi-sig-list/sign-efi-sig-list)
  - mokutil
  - openssl
  - util-linux (for uuidgen)
Then rerun ./scripts/secure-boot/create-secureboot-bootable-media.sh.
MSG
