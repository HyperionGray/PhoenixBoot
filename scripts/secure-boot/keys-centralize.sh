#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."

# Migrate legacy key layout into a centralized structure:
#   out/keys/mok          -> MOK: certs/keys for kernel module signing
#   out/keys/secure_boot  -> Secure Boot PK/KEK/db materials
# Optionally prune legacy locations after creating a backup archive.
# Usage:
#   scripts/keys-centralize.sh [--prune] [--dry-run]
# Options:
#   --prune      move remaining legacy paths into a gzip backup and remove them
#   --dry-run    show the actions without mutating files

ROOT_OUT="out/keys"
MOK_DIR="$ROOT_OUT/mok"
SB_DIR="$ROOT_OUT/secure_boot"
BACKUP_DIR="$ROOT_OUT/backups"

mkdir -p "$MOK_DIR" "$SB_DIR"

DRY_RUN=0
PRUNE=0

usage() {
  cat <<EOF
Usage: $0 [--prune] [--dry-run]

Options:
  --prune      create a legacy backup and remove migrated paths
  --dry-run    print actions without modifying files
  -h, --help   show this message
EOF
}

die() {
  echo "☠ $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --prune)
      PRUNE=1
      shift
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

run() { if [ "$DRY_RUN" = 1 ]; then echo "DRY: $*"; else eval "$*"; fi }

move_if_exists() {
  local src="$1" dest_dir="$2"
  [ -f "$src" ] || return 0
  local base
  base=$(basename "$src")
  if [ -f "$dest_dir/$base" ]; then
    # If same content, remove duplicate and keep one
    if cmp -s "$src" "$dest_dir/$base"; then
      run rm -f "$src"
      return 0
    else
      # Keep both by timestamp suffix
      run cp -a "$src" "$dest_dir/${base}.$(date +%s)"
      run rm -f "$src"
      return 0
    fi
  fi
  run mv "$src" "$dest_dir/"
}

# MOK candidates (legacy root)
move_if_exists "$ROOT_OUT/PGMOK.crt" "$MOK_DIR"
move_if_exists "$ROOT_OUT/PGMOK.key" "$MOK_DIR"
move_if_exists "$ROOT_OUT/PGMOK.der" "$MOK_DIR"
move_if_exists "$ROOT_OUT/PGMOK.pem" "$MOK_DIR"
# Any phoenixguard-mok*.der
for f in "$ROOT_OUT"/*mok*.der; do [ -e "$f" ] && move_if_exists "$f" "$MOK_DIR" || true; done

# Secure Boot materials (typical names)
for f in \
  "$ROOT_OUT/PK.key" "$ROOT_OUT/PK.crt" "$ROOT_OUT/PK.esl" "$ROOT_OUT/PK.auth" \
  "$ROOT_OUT/KEK.key" "$ROOT_OUT/KEK.crt" "$ROOT_OUT/KEK.esl" "$ROOT_OUT/KEK.auth" \
  "$ROOT_OUT/db.key" "$ROOT_OUT/db.crt" "$ROOT_OUT/db.esl" "$ROOT_OUT/db.auth"; do
  [ -e "$f" ] && move_if_exists "$f" "$SB_DIR" || true
done

# Optional: symlinks for backward compatibility (kept unless pruned)
link_safe() {
  local target="$1" linkpath="$2"
  [ -e "$target" ] || return 0
  [ -e "$linkpath" ] && return 0
  run ln -s "$target" "$linkpath"
}

if [ "$PRUNE" != 1 ]; then
  link_safe "$MOK_DIR/PGMOK.crt" "$ROOT_OUT/PGMOK.crt"
  link_safe "$MOK_DIR/PGMOK.key" "$ROOT_OUT/PGMOK.key"
  link_safe "$MOK_DIR/PGMOK.der" "$ROOT_OUT/PGMOK.der"
  link_safe "$MOK_DIR/PGMOK.pem" "$ROOT_OUT/PGMOK.pem"
fi

echo -e "Centralized:\n  MOK dir:        $MOK_DIR\n  Secure Boot dir: $SB_DIR"

# Prune legacy paths if requested
if [ "$PRUNE" = 1 ]; then
  TS=$(date -u +%Y%m%d_%H%M%S)
  run mkdir -p "$BACKUP_DIR"
  ARCHIVE="$BACKUP_DIR/keys_legacy_$TS.tar.gz"
  echo "Creating backup: $ARCHIVE"
  # Collect legacy paths to archive
  to_archive=()
  for d in \
    "keys" \
    "utils/keys" \
    "secureboot_certs" \
    "build/keys" \
    ; do
    [ -e "$d" ] && to_archive+=("$d")
  done
  # Include root-level duplicates in out/keys
  for f in "$ROOT_OUT"/PGMOK.* "$ROOT_OUT"/*mok*.der; do [ -e "$f" ] && to_archive+=("$f"); done
  if [ ${#to_archive[@]} -gt 0 ]; then
    run tar -czf "$ARCHIVE" --ignore-failed-read "${to_archive[@]}"
  fi
  echo "Backup created. Removing legacy paths..."
  for p in "${to_archive[@]}"; do run rm -rf "$p"; done
  # Also remove any symlinks we created for compatibility
  for s in "$ROOT_OUT/PGMOK.crt" "$ROOT_OUT/PGMOK.key" "$ROOT_OUT/PGMOK.der" "$ROOT_OUT/PGMOK.pem"; do
    [ -L "$s" ] && run rm -f "$s" || true
  done
  echo "Prune complete. Backup saved to: $ARCHIVE"
fi
