#!/usr/bin/env bash
set -euo pipefail

# Verify Secure Boot configuration and status
# Checks UEFI Secure Boot state, enrolled keys, and MOK certificates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Verifying Secure Boot configuration..."
exec bash "${SCRIPT_DIR}/scripts/verify-sb.sh"
