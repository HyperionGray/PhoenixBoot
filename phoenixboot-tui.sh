#!/usr/bin/env bash
# PhoenixBoot TUI launcher.
# Supports running from any directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_ONLY=0
ALLOW_AUTO_INSTALL=1

show_usage() {
    echo "Usage: $0 [--check] [--no-install]"
    echo ""
    echo "Options:"
    echo "  --check       Validate launcher dependencies and exit"
    echo "  --no-install  Do not auto-install Python TUI dependencies"
}

find_phoenix_root() {
    if [ -f "${SCRIPT_DIR}/pf.py" ] && [ -d "${SCRIPT_DIR}/scripts" ]; then
        echo "${SCRIPT_DIR}"
        return 0
    fi

    if [ -f "pf.py" ] && [ -d "scripts" ]; then
        pwd
        return 0
    fi

    if [ -n "${PHOENIX_ROOT:-}" ] && [ -f "${PHOENIX_ROOT}/pf.py" ]; then
        echo "${PHOENIX_ROOT}"
        return 0
    fi

    local current="$PWD"
    local max_depth=8
    local depth=0

    while [ "$current" != "/" ] && [ "$depth" -lt "$max_depth" ]; do
        if [ -f "${current}/pf.py" ] && [ -d "${current}/scripts" ]; then
            echo "${current}"
            return 0
        fi
        current="$(dirname "$current")"
        depth=$((depth + 1))
    done

    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --check)
            CHECK_ONLY=1
            ;;
        --no-install)
            ALLOW_AUTO_INSTALL=0
            ;;
        -h|--help|help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: unknown option '$1'"
            show_usage
            exit 1
            ;;
    esac
    shift
done

if ! PHOENIX_ROOT="$(find_phoenix_root)"; then
    echo "Error: Cannot locate PhoenixBoot root."
    echo "Run this from the repository, near it, or set PHOENIX_ROOT."
    exit 1
fi

TUI_APP="${PHOENIX_ROOT}/containers/tui/app/phoenixboot_tui.py"

if [ ! -f "${TUI_APP}" ]; then
    echo "Error: TUI app missing at ${TUI_APP}"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 not found. Please install Python 3.8+"
    exit 1
fi

if ! python3 -c "import textual" >/dev/null 2>&1; then
    if [ "$CHECK_ONLY" -eq 1 ] || [ "$ALLOW_AUTO_INSTALL" -eq 0 ]; then
        echo "Error: Python module 'textual' is missing."
        echo "Install with: python3 -m pip install --user textual rich pyyaml"
        exit 1
    fi

    echo "Installing TUI dependencies (textual, rich, pyyaml)..."
    python3 -m pip install --user textual rich pyyaml
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
    echo "TUI launcher check passed."
    echo "PhoenixBoot root: ${PHOENIX_ROOT}"
    echo "TUI app: ${TUI_APP}"
    exit 0
fi

echo "Launching PhoenixBoot TUI from: ${PHOENIX_ROOT}"
cd "${PHOENIX_ROOT}"
python3 "${TUI_APP}"
