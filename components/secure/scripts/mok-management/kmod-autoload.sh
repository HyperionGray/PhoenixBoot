#!/usr/bin/env bash
set -euo pipefail

find_phoenix_root() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    if [ -f "$dir/pf.py" ] && [ -f "$dir/Pfyfile.pf" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PHOENIX_ROOT="${PHOENIX_ROOT:-$(find_phoenix_root "$SCRIPT_DIR")}"
cd "$PHOENIX_ROOT"

# Configure a module to autoload at boot via systemd modules-load.d
# Usage: kmod-autoload.sh <module_name>

MOD=${1:-}
if [ -z "$MOD" ]; then
  echo "Usage: $0 <module_name>"; exit 1
fi

CONF="/etc/modules-load.d/phoenixguard.conf"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

if [ -f "$CONF" ]; then
  sudo cp -a "$CONF" "$TMP"
else
  : > "$TMP"
fi

# Ensure the module name appears exactly once
if ! grep -qE "^${MOD}(\s|$)" "$TMP"; then
  echo "$MOD" >> "$TMP"
fi

sudo install -D -m 0644 "$TMP" "$CONF"
sudo depmod -a "$(uname -r)" || true

echo "Configured autoload for module: $MOD"
echo "File: $CONF"
