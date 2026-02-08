#!/usr/bin/env bash
# create-secureboot-bootable-media.sh
#
# Sanity-first SecureBoot media workflow:
#   1) Ask whether to (re)generate Secure Boot keys (PK/KEK/db)
#   2) Either:
#      - write a bootable ISO directly to a user-selected USB device, OR
#      - create a ready-to-dd image at out/esp/secureboot-bootable.img
#
# This intentionally avoids:
#   - building custom ESP images
#   - loop-mounting images
#   - guessing filesystem overhead / ISO copy sizing
#
# It expects a hybrid ISO (most Linux distro ISOs). If your ISO is not hybrid,
# use a tool like Rufus/Etcher to write it.
#
# Recommended:
#   ./create-secureboot-bootable-media.sh --iso /path/to.iso --usb-device /dev/sdX

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR"
ISO_PATH=""
USB_DEVICE=""

KEY_MODE="prompt"   # prompt|new|reuse|skip
ASSUME_YES=0
if [ -n "${PFY_ASSUME_YES:-}" ]; then
  ASSUME_YES=1
fi
DRY_RUN=0
VERIFY_WRITE=0

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }

is_tty() { [ -t 0 ] && [ -t 1 ]; }

usage() {
  cat <<'EOF'
Usage:
  create-secureboot-bootable-media.sh --iso /path/to.iso [--usb-device /dev/sdX] [options]

What it does:
  - Optionally (re)generates Secure Boot keys (PK/KEK/db) and enrollment .auth files
  - If --usb-device is set: writes the ISO directly to the selected USB device (DESTRUCTIVE)
  - If --usb-device is omitted: creates out/esp/secureboot-bootable.img (ready to dd)

Options:
  --iso PATH             Path to ISO (prompts if omitted)
  --usb-device DEV       Target device (e.g. /dev/sdb). If omitted, creates out/esp/secureboot-bootable.img.
  --new-keys             Force new keys (backs up existing keys first)
  --reuse-keys           Reuse existing keys (generate if missing)
  --skip-keys            Do not touch keys
  --yes                  Skip interactive confirmations (DANGEROUS)
  --verify               Verify the write by comparing bytes (slow)
  --dry-run              Print what would run, but do not write
  -h, --help             Show help

Examples:
  ./create-secureboot-bootable-media.sh --iso ubuntu.iso --usb-device /dev/sdb
  ./create-secureboot-bootable-media.sh --iso ubuntu.iso --usb-device /dev/sdb --new-keys
  ./create-secureboot-bootable-media.sh --iso ubuntu.iso
EOF
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }

stat_bytes() {
  local path="$1"
  stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || return 1
}

lsblk_bytes() {
  local dev="$1"
  # bytes, no headings, disk-only row
  lsblk -bdno SIZE "$dev" 2>/dev/null | awk 'NR==1 {print $1}'
}

confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  is_tty || die "${prompt} (non-interactive; pass --yes to override)"
  read -r -p "$prompt [y/N]: " ans
  case "${ans:-}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

prompt_value() {
  local prompt="$1" default="${2:-}"
  is_tty || die "${prompt} (non-interactive; pass CLI flags instead)"
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " v
    printf '%s' "${v:-$default}"
  else
    read -r -p "$prompt: " v
    printf '%s' "$v"
  fi
}

backup_keys_if_present() {
  local ts backup_root
  ts="$(date +%Y%m%d-%H%M%S)"
  backup_root="out/backups/keys-${ts}"
  mkdir -p "$backup_root/keys" "$backup_root/securevars"

  local moved=0
  for f in keys/PK.key keys/PK.crt keys/PK.cer keys/KEK.key keys/KEK.crt keys/KEK.cer keys/db.key keys/db.crt keys/db.cer; do
    if [ -e "$f" ]; then
      mv "$f" "$backup_root/keys/"
      moved=1
    fi
  done
  for f in out/securevars/PK.auth out/securevars/KEK.auth out/securevars/db.auth out/securevars/PK.esl out/securevars/KEK.esl out/securevars/db.esl; do
    if [ -e "$f" ]; then
      mkdir -p "$backup_root/securevars"
      mv "$f" "$backup_root/securevars/"
      moved=1
    fi
  done

  if [ "$moved" -eq 1 ]; then
    note "Backed up existing key material to: $backup_root"
  fi
}

ensure_keys() {
  case "$KEY_MODE" in
    skip) return 0 ;;
    new)
      backup_keys_if_present
      ;;
    reuse|prompt)
      ;;
    *)
      die "Invalid KEY_MODE: $KEY_MODE"
      ;;
  esac

  # Generate keys if missing (or after backup in --new-keys mode)
  if [ ! -f keys/PK.key ] || [ ! -f keys/KEK.key ] || [ ! -f keys/db.key ]; then
    require_cmd openssl
    note "Generating Secure Boot keys (PK/KEK/db)..."
    if [ "$DRY_RUN" -eq 1 ]; then
      note "+ bash scripts/secure-boot/generate-sb-keys.sh"
    else
      bash scripts/secure-boot/generate-sb-keys.sh
    fi
  else
    note "Using existing Secure Boot keys in ./keys/"
  fi

  # Generate enrollment auth files if missing
  if [ ! -f out/securevars/PK.auth ] || [ ! -f out/securevars/KEK.auth ] || [ ! -f out/securevars/db.auth ]; then
    require_cmd cert-to-efi-sig-list
    require_cmd sign-efi-sig-list
    require_cmd uuidgen
    note "Creating Secure Boot enrollment files (.auth)..."
    if [ "$DRY_RUN" -eq 1 ]; then
      note "+ bash scripts/secure-boot/create-auth-files.sh"
    else
      bash scripts/secure-boot/create-auth-files.sh
    fi
  else
    note "Enrollment files already present in out/securevars/"
  fi
}

create_output_image() {
  local out_dir="out/esp"
  local out_img="$out_dir/secureboot-bootable.img"
  mkdir -p "$out_dir"

  note "Creating: $out_img"
  if [ "$DRY_RUN" -eq 1 ]; then
    note "+ cp -f \"$ISO_PATH\" \"$out_img\""
  else
    cp -f "$ISO_PATH" "$out_img"
  fi

  note ""
  note "Ready to write to USB:"
  note "  sudo dd if=$out_img of=/dev/sdX bs=4M status=progress conv=fsync"
}

resolve_write_target() {
  [ -n "$USB_DEVICE" ] || die "Missing --usb-device"
  [ -b "$USB_DEVICE" ] || die "Not a block device: $USB_DEVICE"

  local dev_type
  dev_type="$(lsblk -no TYPE "$USB_DEVICE" 2>/dev/null | head -n1 || true)"
  if [ "$dev_type" != "disk" ]; then
    die "Refusing to write to non-disk device: $USB_DEVICE (type: ${dev_type:-unknown}). Use the whole-disk path like /dev/sdX."
  fi
}

preflight_space_check() {
  local iso_bytes dev_bytes
  iso_bytes="$(stat_bytes "$ISO_PATH")" || die "Failed to stat ISO: $ISO_PATH"
  dev_bytes="$(lsblk_bytes "$USB_DEVICE")"
  [ -n "$dev_bytes" ] || die "Failed to read device size for $USB_DEVICE"

  if [ "$dev_bytes" -lt "$iso_bytes" ]; then
    die "USB device is too small: device=${dev_bytes}B iso=${iso_bytes}B"
  fi
}

unmount_children() {
  local dev="$1"
  local child
  while IFS= read -r child; do
    [ -n "$child" ] || continue
    sudo umount "$child" >/dev/null 2>&1 || true
  done < <(lsblk -lnpo NAME "$dev" 2>/dev/null | tail -n +2)
}

dd_supports_status() {
  dd --help 2>&1 | grep -q "status="
}

write_iso_to_usb() {
  require_cmd dd
  require_cmd lsblk
  require_cmd sudo

  note ""
  note "Target device details:"
  lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINTS "$USB_DEVICE" || true
  note ""

  warn "This will ERASE ALL DATA on $USB_DEVICE"
  if ! confirm "Proceed to write ISO to ${USB_DEVICE}?"; then
    die "Aborted by user"
  fi

  if [ "$DRY_RUN" -eq 0 ]; then
    sudo -v
    unmount_children "$USB_DEVICE"
  fi

  local -a dd_args
  dd_args=(if="$ISO_PATH" of="$USB_DEVICE" bs=4M conv=fsync)
  if dd_supports_status; then
    dd_args+=(status=progress)
  fi

  note ""
  if [ "$DRY_RUN" -eq 1 ]; then
    note "+ sudo dd ${dd_args[*]}"
    note "+ sudo sync"
  else
    sudo dd "${dd_args[@]}"
    sudo sync
  fi

  if [ "$VERIFY_WRITE" -eq 1 ]; then
    require_cmd cmp
    local iso_bytes
    iso_bytes="$(stat_bytes "$ISO_PATH")" || die "Failed to stat ISO: $ISO_PATH"
    note ""
    note "Verifying write (this may take a while)..."
    if [ "$DRY_RUN" -eq 1 ]; then
      note "+ sudo cmp -n ${iso_bytes} \"$ISO_PATH\" \"$USB_DEVICE\""
    else
      sudo cmp -n "$iso_bytes" "$ISO_PATH" "$USB_DEVICE"
      note "Verification OK"
    fi
  fi
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)
      ISO_PATH="${2:-}"
      shift 2
      ;;
    --usb-device)
      USB_DEVICE="${2:-}"
      shift 2
      ;;
    --new-keys)
      KEY_MODE="new"
      shift
      ;;
    --reuse-keys)
      KEY_MODE="reuse"
      shift
      ;;
    --skip-keys)
      KEY_MODE="skip"
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --verify)
      VERIFY_WRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1 (use --help)"
      ;;
  esac
done

main() {
  [ -n "$ISO_PATH" ] || ISO_PATH="$(prompt_value "Enter path to ISO")"
  [ -n "$ISO_PATH" ] || die "Missing --iso"
  [ -f "$ISO_PATH" ] || die "ISO file not found: $ISO_PATH"

  if [ "$KEY_MODE" = "prompt" ]; then
    if ! is_tty; then
      KEY_MODE="reuse"
    fi
  fi

  if [ "$KEY_MODE" = "prompt" ]; then
    if [ -f keys/PK.key ] || [ -f keys/KEK.key ] || [ -f keys/db.key ]; then
      if confirm "Existing Secure Boot keys found. Generate NEW keys?"; then
        KEY_MODE="new"
      else
        KEY_MODE="reuse"
      fi
    else
      if confirm "No Secure Boot keys found. Generate keys now?"; then
        KEY_MODE="reuse"
      else
        KEY_MODE="skip"
      fi
    fi
  fi

  note ""
  note "ISO: $ISO_PATH"
  note "USB device: ${USB_DEVICE:-<none>}"
  note "Keys: $KEY_MODE"
  note ""

  if [ "$KEY_MODE" != "skip" ]; then
    ensure_keys
  fi

  if [ -z "$USB_DEVICE" ]; then
    create_output_image
    return 0
  fi

  resolve_write_target
  preflight_space_check
  write_iso_to_usb

  note ""
  note "Done."
  note "Next steps:"
  note "  - Boot from the USB and install your OS."
  note "  - If you generated keys: keep ./keys/ backed up (private material)."
}

main "$@"
