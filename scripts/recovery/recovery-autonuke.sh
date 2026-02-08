#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

info "☠ Launching AutoNuke recovery orchestrator"
SCRIPT="nuclear-cd-build/iso/recovery/scripts/autonuke.py"

if [ ! -f "$SCRIPT" ]; then
  die "AutoNuke script not found at $SCRIPT"
fi

PY="$(resolve_python)" || die "No usable Python found (tried VENV_PY/VENV_BIN, ./venv/.venv, python3/python)"

exec "$PY" "$SCRIPT"
