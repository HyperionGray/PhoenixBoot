#!/usr/bin/env bash
# Description: Lints C and Python source files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi

cd "${PROJECT_ROOT}"
mkdir -p out/lint

C_LOG="out/lint/c_lint.log"
PY_LOG="out/lint/python_lint.log"
: > "${C_LOG}"
: > "${PY_LOG}"

# Lint tracked C/C headers
while IFS= read -r file; do
    [ -f "$file" ] || continue
    echo "Linting $file" >> "${C_LOG}"
    # Use basic syntax checking since full toolchain may be unavailable.
    gcc -fsyntax-only "$file" >> "${C_LOG}" 2>&1 || true
done < <(git ls-files '*.c' '*.h')

PYTHON_BIN="${PYTHON:-python3}"
while IFS= read -r file; do
    [ -f "$file" ] || continue
    echo "Linting $file" >> "${PY_LOG}"
    "${PYTHON_BIN}" -m py_compile "$file" >> "${PY_LOG}" 2>&1 || true
done < <(git ls-files '*.py')

echo "Static analysis complete - see out/lint/"

