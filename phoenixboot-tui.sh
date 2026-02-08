#!/bin/bash
# PhoenixBoot TUI Launcher
# Launch the interactive Terminal User Interface

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR"
TUI_APP="containers/tui/app/phoenixboot_tui.py"

# Ensure we're running from the PhoenixBoot repo root regardless of caller CWD
if [ ! -f "pf.py" ]; then
    echo "Error: pf.py not found at repo root: $SCRIPT_DIR"
    exit 1
fi

# Check Python version
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 not found. Please install Python 3.8+"
    exit 1
fi

# Check for textual library
if ! python3 -c "import textual" 2>/dev/null; then
    echo "Installing TUI dependencies..."
    python3 -m pip install --user textual rich pyyaml || {
        echo "Error: Failed to install dependencies"
        echo "Try: python3 -m pip install textual rich pyyaml"
        exit 1
    }
fi

# Launch TUI
echo "🔥 Launching PhoenixBoot TUI..."
python3 "${TUI_APP}"
