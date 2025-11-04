#!/usr/bin/env bash
set -euo pipefail

# Validate ESP (EFI System Partition) contents
# Checks integrity and completeness of bootable ESP image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Validating ESP contents..."
exec bash "${SCRIPT_DIR}/scripts/validate-esp.sh"
