#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

info "☠  Kernel module auto-sign (non-interactive)"

PYTHON_BIN=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)

dedupe_module_signatures() {
  local module="$1"
  [ -n "$PYTHON_BIN" ] || return 0
  local cleaned
  cleaned=$(
  "$PYTHON_BIN" - "$module" <<'PY'
import pathlib, sys

marker = b"~Module signature appended~"
path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
positions = []
start = 0
while True:
    idx = data.find(marker, start)
    if idx == -1:
        break
    positions.append(idx)
    start = idx + len(marker)
if len(positions) <= 1:
    sys.exit(0)
new_data = data[:positions[0]] + data[positions[-1]:]
if new_data == data:
    sys.exit(0)
path.write_bytes(new_data)
print(f"Cleaned duplicate signature blocks in {path}")
PY
  )
  if [ -n "${cleaned:-}" ]; then
    info "$cleaned"
  fi
}


usage() {
  cat <<'EOF'
Usage: sign-kmods.sh [OPTIONS] [DIR...]

Options:
  --key PATH     Signing key (default: out/keys/mok/PGMOK.key)
  --cert PATH    Signing certificate (default: out/keys/mok/PGMOK.crt)
  --algo ALGO    Hashing algorithm for the sign-file helper (default: sha256)
  --dir PATH     Additional directory to scan for modules (repeatable)
  -h, --help     Show this message

Positional DIR arguments behave like repeated --dir entries.
EOF
  exit 0
}

DEFAULT_KMOD_KEY=out/keys/mok/PGMOK.key
DEFAULT_KMOD_CERT=out/keys/mok/PGMOK.crt
DEFAULT_KMOD_ALGO=sha256
DEFAULT_KMOD_DIRS=

KMOD_KEY_ARG=""
KMOD_CERT_ARG=""
KMOD_ALGO_ARG=""
declare -a KMOD_DIR_ARGS=()
REL=$(uname -r)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)
      [ $# -gt 1 ] || die "Missing value for --key"
      KMOD_KEY_ARG="$2"
      shift 2
      ;;
    --cert)
      [ $# -gt 1 ] || die "Missing value for --cert"
      KMOD_CERT_ARG="$2"
      shift 2
      ;;
    --algo)
      [ $# -gt 1 ] || die "Missing value for --algo"
      KMOD_ALGO_ARG="$2"
      shift 2
      ;;
    --dir)
      [ $# -gt 1 ] || die "Missing value for --dir"
      KMOD_DIR_ARGS+=("$2")
      shift 2
      ;;
    --dir=*)
      KMOD_DIR_ARGS+=("${1#*=}")
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      KMOD_DIR_ARGS+=("$1")
      shift
      ;;
  esac
done

KMOD_KEY="${KMOD_KEY_ARG:-$DEFAULT_KMOD_KEY}"
KMOD_CERT="${KMOD_CERT_ARG:-$DEFAULT_KMOD_CERT}"
KMOD_ALGO="${KMOD_ALGO_ARG:-$DEFAULT_KMOD_ALGO}"
if [ ${#KMOD_DIR_ARGS[@]} -gt 0 ]; then
  KMOD_DIRS="${KMOD_DIR_ARGS[*]}"
else
  KMOD_DIRS="$DEFAULT_KMOD_DIRS"
fi

[ -f "$KMOD_KEY" ] || die "Signing key not found: $KMOD_KEY"
[ -f "$KMOD_CERT" ] || die "Signing cert not found: $KMOD_CERT"

# Locate the kernel's sign-file helper
find_sign_file() {
  local rel="$1"
  local cands=(
    "/usr/src/linux-headers-${rel}/scripts/sign-file"
    "/lib/modules/${rel}/build/scripts/sign-file"
    "/usr/src/kernels/${rel}/scripts/sign-file"
  )
  for p in "${cands[@]}"; do
    [ -x "$p" ] && { echo "$p"; return 0; }
  done
  # Best-effort search to cover unusual layouts
  local found
  found=$(find /usr/src /lib/modules -maxdepth 4 -type f -name sign-file 2>/dev/null | head -n1 || true)
  [ -n "$found" ] && { echo "$found"; return 0; }
  return 1
}

SIGN_FILE=$(find_sign_file "$REL") || die "Could not locate kernel scripts/sign-file for ${REL}. Install kernel headers."
ok "Using sign-file: $SIGN_FILE"

# Build module list
TMP_LIST=$(mktemp)
trap 'rm -f "$TMP_LIST"' EXIT

# 1) Loaded modules -> on-disk .ko path via modinfo -n
if [ -r /proc/modules ]; then
  awk '{print $1}' /proc/modules | while read -r name; do
    p=$(modinfo -n "$name" 2>/dev/null || true)
    [ -n "$p" ] && [ -f "$p" ] && echo "$p" >> "$TMP_LIST" || true
  done
fi

# 2) DKMS modules (built trees)
if [ -d /var/lib/dkms ]; then
  find /var/lib/dkms -type f -name '*.ko' -print >> "$TMP_LIST" 2>/dev/null || true
fi

# 3) Optional custom module directories (space-separated)
if [ -n "$KMOD_DIRS" ]; then
  for d in $KMOD_DIRS; do
    [ -d "$d" ] && find "$d" -type f -name '*.ko' -print >> "$TMP_LIST" 2>/dev/null || true
  done
fi

# Deduplicate
MODULES=$(sort -u "$TMP_LIST")
COUNT=$(printf '%s\n' "$MODULES" | sed '/^$/d' | wc -l | awk '{print $1}')
info "Discovered ${COUNT} module candidates"

SIGNED=0
ALREADY=0
FAILED=0

sign_one() {
  local f="$1"
  dedupe_module_signatures "$f"
  # Already signed? (modinfo fields: sig_id/signer may be empty if unsigned)
  if modinfo -F sig_id "$f" 2>/dev/null | grep -q .; then
    ALREADY=$((ALREADY+1))
    return 0
  fi
  # Need root to modify files under /lib/modules
  if sudo -n true 2>/dev/null; then
    if sudo -n "$SIGN_FILE" "$KMOD_ALGO" "$KMOD_KEY" "$KMOD_CERT" "$f"; then
      SIGNED=$((SIGNED+1))
      return 0
    else
      FAILED=$((FAILED+1))
      return 1
    fi
  else
    # Try without sudo (works only if user has write perms)
    if "$SIGN_FILE" "$KMOD_ALGO" "$KMOD_KEY" "$KMOD_CERT" "$f" 2>/dev/null; then
      SIGNED=$((SIGNED+1))
      return 0
    else
      warn "Cannot sign (no sudo and not writable): $f"
      FAILED=$((FAILED+1))
      return 1
    fi
  fi
}

# Iterate modules
IFS=$'\n'
for f in $MODULES; do
  [ -n "$f" ] || continue
  sign_one "$f" || true
done
unset IFS

# Summary
echo ""
ok "Module signing complete"
echo "  Signed:        $SIGNED"
echo "  Already signed: $ALREADY"
echo "  Failed:        $FAILED"

if [ "$FAILED" -gt 0 ]; then
  warn "Some modules could not be signed. Ensure sudo is available and kernel headers for ${REL} are installed."
fi

info "Tip: Ensure your MOK certificate is enrolled so the kernel accepts signed modules: $KMOD_CERT"
