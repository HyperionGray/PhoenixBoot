#!/usr/bin/env bash
# Description: Runs all tests found in the staging/tests directory.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
    cat <<'EOF'
Usage: run-staging-tests.sh [--venv PATH]

Options:
  --venv PATH    Virtualenv root to activate before running tests (default: $HOME/.venv)
  -h, --help     Show this message
EOF
    exit 0
}

VENV_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --venv)
      VENV_PATH="${2:-}"
      shift 2
      ;;
    --venv=*)
      VENV_PATH="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -d staging/tests ] && [ -n "$(find staging/tests -name '*.py' -o -name '*.sh' 2>/dev/null)" ]; then
    echo "Running staging tests..."
    # Activate virtual environment if it exists
    if [ -n "$VENV_PATH" ]; then
        source "${VENV_PATH}/bin/activate"
    elif [ -d "${HOME}/.venv" ]; then
        source "${HOME}/.venv/bin/activate"
    fi
    find staging/tests -name '*.py' -exec python3 {} \;
    find staging/tests -name '*.sh' -exec bash {} \;
fi
