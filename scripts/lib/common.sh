#!/usr/bin/env bash
set -euo pipefail

# Common helpers for PhoenixGuard scripts
# Usage: source "$(dirname "$0")/lib/common.sh"

COMMON_SH_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PHOENIX_ROOT="${PHOENIX_ROOT:-$(cd -- "${COMMON_SH_DIR}/../.." && pwd -P)}"
export PHOENIX_ROOT

log()  { printf '%s\n' "$*"; }
info() { printf 'ℹ☠  %s\n' "$*"; }
ok()   { printf '☠ %s\n' "$*"; }
warn() { printf '☠  %s\n' "$*"; }
err()  { printf '☠ %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

resolve_root_disk() {
  local root_source
  root_source="$(findmnt -no SOURCE / 2>/dev/null || true)"
  [ -n "$root_source" ] || return 1
  root_source="$(readlink -f "$root_source" 2>/dev/null || echo "$root_source")"
  [ -b "$root_source" ] || return 1

  local cur="$root_source"
  while true; do
    local pk
    pk="$(lsblk -no PKNAME "$cur" 2>/dev/null | awk 'NR==1{print $1}')"
    if [ -z "$pk" ]; then
      printf '%s\n' "$cur"
      return 0
    fi
    cur="/dev/${pk}"
  done
}

guard_not_root_disk() {
  local device="$1"
  local force="${2:-0}"

  if [ "$force" = "1" ]; then
    warn "--force-root supplied; overriding root-disk protection"
    return 0
  fi

  local root_disk=""
  root_disk="$(resolve_root_disk 2>/dev/null || true)"
  if [ -n "$root_disk" ]; then
    case "$device" in
      "$root_disk"|"${root_disk}"[0-9]*|"${root_disk}"p[0-9]*)
        die "Refusing to operate on root disk ($root_disk). Pass --force-root to override."
        ;;
    esac
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

unmount_if_mounted() {
  local mnt="$1"
  if mountpoint -q "$mnt" 2>/dev/null; then
    warn "Unmounting previous $mnt"
    sudo umount "$mnt" || sudo umount -l "$mnt" || true
  fi
  rmdir "$mnt" 2>/dev/null || true
}

detach_loops_for_image() {
  local img="$1"
  local loops
  loops=$(sudo losetup -j "$img" 2>/dev/null | cut -d: -f1 || true)
  if [ -n "${loops}" ]; then
    warn "Detaching loop devices for $img: ${loops}"
    echo "$loops" | xargs -r -n1 sudo losetup -d || true
  fi
}

resolve_usb_partition() {
  local device="$1"
  local base
  base=$(basename "$device")
  local candidates
  if [[ "$base" =~ [0-9]$ ]]; then
    candidates=("${device}p1" "${device}1")
  else
    candidates=("${device}1" "${device}p1")
  fi
  local cand
  for cand in "${candidates[@]}"; do
    if [ -b "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  die "Cannot find first partition for $device (tried ${candidates[*]}); create a FAT partition first."
}

mount_rw_loop() {
  local img="$1" mnt="$2"
  ensure_dir "$mnt"
  sudo mount -o loop,rw "$img" "$mnt" || die "Failed to mount $img rw at $mnt"
}

discover_ovmf() {
  local code vars
  if [ -f "${PHOENIX_ROOT}/out/setup/ovmf_code_path" ] && [ -f "${PHOENIX_ROOT}/out/setup/ovmf_vars_path" ]; then
    code=$(cat "${PHOENIX_ROOT}/out/setup/ovmf_code_path")
    vars=$(cat "${PHOENIX_ROOT}/out/setup/ovmf_vars_path")
    [ -f "$code" ] && [ -f "$vars" ] || return 1
    printf '%s\n' "$code" "$vars"
    return 0
  fi
  return 1
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

resolve_python() {
  local project_root="${1:-}"
  if [ -z "${project_root}" ]; then
    project_root="${PHOENIX_ROOT:-$(pwd)}"
  fi

  local candidates=()

  if [ -n "${VENV_PY:-}" ]; then
    candidates+=("${VENV_PY}")
  fi
  if [ -n "${VENV_BIN:-}" ]; then
    candidates+=("${VENV_BIN}/python3" "${VENV_BIN}/python")
  fi

  candidates+=(
    "${project_root}/venv/bin/python3"
    "${project_root}/venv/bin/python"
    "${project_root}/.venv/bin/python3"
    "${project_root}/.venv/bin/python"
    python3
    python
  )

  local cand
  for cand in "${candidates[@]}"; do
    if command -v "${cand}" >/dev/null 2>&1; then
      printf '%s\n' "${cand}"
      return 0
    fi
  done

  return 1
}
