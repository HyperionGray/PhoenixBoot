#!/usr/bin/env bash
set -euo pipefail

# Install Clean GRUB Boot to ESP
# Sets up a minimal, clean GRUB configuration on the EFI System Partition
#
# ☠ WARNING: May conflict with existing GRUB configurations!
# See scripts/install_clean_grub_boot.sh for detailed documentation
#
# Usage:
#   sudo ./install-clean-grub.sh --esp /boot/efi --root-uuid <UUID> [OPTIONS]
#
# Required:
#   --esp PATH         Path to ESP mount point (e.g., /boot/efi)
#   --root-uuid UUID   Root filesystem UUID
#
# Optional:
#   --shim PATH        Path to shimx64.efi.signed
#   --grub-efi PATH    Path to grubx64.efi
#   --vmlinuz PATH     Path to kernel image
#   --initrd PATH      Path to initrd image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec bash "${SCRIPT_DIR}/scripts/install_clean_grub_boot.sh" "$@"
