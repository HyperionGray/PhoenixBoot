#!/usr/bin/env bash
# Description: Formats shell scripts.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Format shell scripts (exclude demo)
(find staging dev wip scripts -type f -name '*.sh' 2>/dev/null || true) | while read -r file; do
    # Basic formatting - ensure executable bit is set where appropriate
    [ -x "$file" ] || chmod +x "$file" 2>/dev/null || true
done

echo "☠ Code formatting complete"
