#!/usr/bin/env bash
# Description: Runs all tests found in the staging/tests directory.

set -euo pipefail

if [ -d staging/tests ] && [ -n "$(find staging/tests -name '*.py' -o -name '*.sh' 2>/dev/null)" ]; then
    echo "Running staging tests..."
    # Activate virtual environment if it exists
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        source "${VIRTUAL_ENV}/bin/activate"
    elif [ -d "${HOME}/.venv" ]; then
        source "${HOME}/.venv/bin/activate"
    fi
    find staging/tests -name '*.py' -exec python3 {} \;
    find staging/tests -name '*.sh' -exec bash {} \;
fi

