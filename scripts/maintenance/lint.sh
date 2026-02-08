#!/usr/bin/env bash
# Description: Lints C and Python source files.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Ensure output directory exists
mkdir -p out/lint
: > out/lint/c_lint.log
: > out/lint/python_lint.log

# Lint C sources in staging and dev (exclude demo)
(find staging dev wip -type f \( -name '*.c' -o -name '*.h' \) 2>/dev/null || true) | while read -r file; do
    echo "Linting $file" >> out/lint/c_lint.log
    # Use basic syntax checking since we may not have full linters
    gcc -fsyntax-only "$file" 2>> out/lint/c_lint.log || true
done

# Lint Python sources
(find staging dev wip scripts -type f -name '*.py' 2>/dev/null || true) | while read -r file; do
    echo "Linting $file" >> out/lint/python_lint.log
    python3 -m py_compile "$file" 2>> out/lint/python_lint.log || true
done

echo "☠ Static analysis complete - see out/lint/"
