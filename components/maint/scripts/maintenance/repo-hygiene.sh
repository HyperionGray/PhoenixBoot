#!/usr/bin/env bash
set -euo pipefail

# Repository hygiene cleanup.
# This script removes stale/generated artifacts that should not live in git history
# and reports high-risk large files that are tracked.
#
# Modes:
#   default (safe): remove known transient files only
#   aggressive: set HYGIENE_AGGRESSIVE=1 to also remove likely generated docs under demo targets

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null || { cd "${SCRIPT_DIR}/../.." && pwd; })"
cd "${PROJECT_ROOT}"

echo "Running repository hygiene cleanup (safe mode)"

# Always-clean generated local artifacts.
shopt -s globstar nullglob
SAFE_GLOBS=(
  "core"
  "core.[0-9]*"
  "*.tmp"
  "*.temp"
  "out/**/*.tmp"
  "out/**/*.temp"
  "out/**/*.log"
  "out/**/*.junit.xml"
  "out/**/*.xml.tmp"
)

removed_any=0
for pattern in "${SAFE_GLOBS[@]}"; do
  while IFS= read -r path; do
    if [ -n "${path}" ] && [ -e "${path}" ]; then
      rm -f -- "${path}"
      echo "Removed stale artifact: ${path}"
      removed_any=1
    fi
  done < <(compgen -G "${pattern}" || true)
done

if [ "${HYGIENE_AGGRESSIVE:-0}" = "1" ]; then
  echo "Aggressive mode enabled: removing generated demo rustdoc artifacts"
  while IFS= read -r p; do
    rm -rf -- "${p}"
    echo "Removed generated demo artifact tree: ${p}"
    removed_any=1
  done < <(compgen -G "examples_and_samples/**/target/doc" || true)
fi

if [ "${removed_any}" = "0" ]; then
  echo "No stale artifacts found for configured patterns."
fi

echo
echo "Tracked files larger than 10MB (review for necessity):"
if ! git ls-files -z | xargs -0 -I{} sh -c '
f="$1"
s=$(stat -c%s "$f" 2>/dev/null || echo 0)
[ "$s" -gt 10485760 ] && printf "%s\t%s\n" "$s" "$f"
' _ {} | sort -nr; then
  true
fi

echo
echo "Repository hygiene cleanup complete."
