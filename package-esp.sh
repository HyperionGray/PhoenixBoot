#!/usr/bin/env bash
set -euo pipefail

# Package a bootable ESP (EFI System Partition) image
# Creates out/esp/esp.img for booting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Packaging bootable ESP image..."
exec bash "${SCRIPT_DIR}/scripts/esp-package.sh"
