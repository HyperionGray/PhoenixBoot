#!/bin/bash
# PhoenixBoot TUI Launcher
# Launch the interactive Terminal User Interface

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_APP="${SCRIPT_DIR}/containers/tui/app/phoenixboot_tui.py"

# Check if running from PhoenixBoot root
if [ ! -f "pf.py" ]; then
    echo "Error: Must run from PhoenixBoot root directory"
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
    pip install --user textual rich pyyaml || {
        echo "Error: Failed to install dependencies"
        echo "Try: pip install textual rich pyyaml"
        exit 1
    }
fi

# Launch TUI
echo "🔥 Launching PhoenixBoot TUI..."
python3 "${TUI_APP}"
