#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

echo "[TEST] pf list works from repo root"
./pf.py list > /dev/null

echo "[TEST] pf list works from subdir"
(cd scripts/testing && ../../pf.py list > /dev/null)

echo "[TEST] Task files reference existing scripts"
PF_FILES=(core.pf secure.pf workflows.pf maint.pf)

mapfile -t SCRIPT_PATHS < <(
  grep -h -oE 'scripts/[A-Za-z0-9_./-]+\.sh' "${PF_FILES[@]}" | sort -u
)

# Built-ins reference this script
SCRIPT_PATHS+=("scripts/system-setup.sh")

missing=0
for s in "${SCRIPT_PATHS[@]}"; do
  if [ ! -f "$s" ]; then
    echo "  ✗ missing: $s"
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  exit 1
fi
echo "  ✓ $(printf '%s\n' "${SCRIPT_PATHS[@]}" | wc -l) scripts found"

echo "[TEST] Scripts pass bash -n"
for s in "${SCRIPT_PATHS[@]}"; do
  bash -n "$s"
done

echo "[TEST] Task names are single tokens (no accidental params)"
bad=0
while IFS= read -r line; do
  # Expected: task <name>
  if ! [[ "$line" =~ ^task[[:space:]][A-Za-z0-9_-]+$ ]]; then
    echo "  ✗ bad task header: $line"
    bad=1
  fi
done < <(grep -h -E '^task ' "${PF_FILES[@]}")
if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "  ✓ task headers look sane"

echo "[TEST] Double-kexec script supports --dry-run"
bash scripts/secure-boot/enable-secureboot-kexec.sh --dry-run >/dev/null 2>&1
bash scripts/secure-boot/enable-secureboot-kexec.sh --direct --dry-run >/dev/null 2>&1
echo "  ✓ ok"

echo "[TEST] os-kmod-sign uses MODULE_PATH (not PATH)"
if grep -q 'task os-kmod-sign' -n core.pf && grep -q 'MODULE_PATH' core.pf && ! grep -q 'Usage: PATH=' core.pf; then
  echo "  ✓ ok"
else
  echo "  ✗ core.pf os-kmod-sign still references PATH"
  exit 1
fi

echo "✓ pf task sanity passed"
