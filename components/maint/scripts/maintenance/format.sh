#!/usr/bin/env bash
# Description: Formats shell scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi

cd "${PROJECT_ROOT}"
mkdir -p out/maintenance

# Prefer shfmt when available; otherwise provide a deterministic no-op report.
if command -v shfmt >/dev/null 2>&1; then
    while IFS= read -r file; do
        [ -f "$file" ] || continue
        shfmt -w "$file" || true
    done < <(git ls-files '*.sh')
    echo "Code formatting complete (shfmt)" | tee -a out/maintenance/format.log
else
    printf '%s\n' \
        "Code formatting skipped: shfmt not installed." \
        "Install shfmt to enable shell script auto-formatting." \
        | tee -a out/maintenance/format.log
fi

