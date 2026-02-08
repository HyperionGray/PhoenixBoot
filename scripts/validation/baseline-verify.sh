#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."
# shellcheck disable=SC1091
source scripts/lib/common.sh

info "☠ Firmware baseline verification (verify-only)"
ensure_dir out/recovery

# Attempt to locate recovery script
CANDIDATES=(
  scripts/hardware_firmware_recovery.py
  nuclear-cd-build/iso/recovery/scripts/hardware_firmware_recovery.py
)

SCRIPT=""
for c in "${CANDIDATES[@]}"; do
  if [ -f "$c" ]; then SCRIPT="$c"; break; fi
done

if [ -z "$SCRIPT" ]; then
  warn "hardware_firmware_recovery.py not found in repository"
  echo "Expected at one of:"
  printf '  - %s\n' "${CANDIDATES[@]}"
  echo "Skipping baseline verification."
  exit 0
fi

PY="$(resolve_python)" || die "No usable Python found (tried VENV_PY/VENV_BIN, ./venv/.venv, python3/python)"

OUT_JSON="out/recovery/firmware_verify.json"

if sudo -n true 2>/dev/null; then
  sudo -n "$PY" "$SCRIPT" --verify-only /dev/null --output "$OUT_JSON" || true
else
  warn "sudo not available non-interactively; attempting without sudo"
  "$PY" "$SCRIPT" --verify-only /dev/null --output "$OUT_JSON" || true
fi

if [ -f "$OUT_JSON" ]; then
  ok "Baseline verification complete: $OUT_JSON"
else
  warn "No output generated; see logs above"
fi
