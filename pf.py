#!/usr/bin/env bash
set -euo pipefail

if command -v pf >/dev/null 2>&1; then
  exec pf "$@"
fi

echo "ERROR: pf runner not found in PATH." >&2
echo "Install pf-runner or make 'pf' available, then retry." >&2
exit 127
