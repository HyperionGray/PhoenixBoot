#!/usr/bin/env bash
# Description: Clean common stale repository artifacts with dry-run by default.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

DRY_RUN="${DRY_RUN:-1}"
if [ "${APPLY:-0}" = "1" ]; then
  DRY_RUN=0
fi

echo "🧽 PhoenixBoot repo tidy"
if [ "${DRY_RUN}" = "1" ]; then
  echo "Mode: DRY_RUN=1 (preview only)"
  echo "Set APPLY=1 to remove files."
else
  echo "Mode: APPLY=1 (changes will be made)"
fi
echo

declare -A CANDIDATES=()

# 1) Tracked .bish-index files are stale index artifacts.
while IFS= read -r path; do
  [ -n "${path}" ] && CANDIDATES["${path}"]=1
done < <(git ls-files | rg '\.bish-index$' || true)

# 2) Common ignored artifacts that still accumulate locally.
while IFS= read -r path; do
  [ -n "${path}" ] && CANDIDATES["${path}"]=1
done < <(
  git ls-files --others --ignored --exclude-standard \
    | rg '(^|/)(__pycache__/|\.pytest_cache/|.*\.pyc$|.*\.pyo$|.*~$|.*\.swp$|.*\.swo$|\.bish-index$)' \
    || true
)

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  echo "✅ No stale artifacts detected."
  exit 0
fi

echo "Found ${#CANDIDATES[@]} stale artifact(s):"
for path in "${!CANDIDATES[@]}"; do
  echo "  - ${path}"
done
echo

if [ "${DRY_RUN}" = "1" ]; then
  echo "✅ Dry run complete. Re-run with APPLY=1 to remove these artifacts."
  exit 0
fi

removed=0
for path in "${!CANDIDATES[@]}"; do
  if [ -d "${path}" ]; then
    rm -rf "${path}"
    removed=$((removed + 1))
  elif [ -f "${path}" ]; then
    rm -f "${path}"
    removed=$((removed + 1))
  fi
done

echo "✅ Removed ${removed} stale artifact(s)."
