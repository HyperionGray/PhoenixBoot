#!/usr/bin/env bash
# Description: Prepares an ESP with an ISO and boots it in QEMU.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
    cat <<'EOF'
Usage: iso-run.sh --iso /path/to/iso

Options:
  --iso PATH      Path to the ISO that should be embedded in the ESP image
  -h, --help      Show this message
EOF
    exit 1
}

ISO_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)
      ISO_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "$ISO_PATH" ] || usage
[ -f "$ISO_PATH" ] || { echo "☠ ISO not found: $ISO_PATH"; exit 1; }

# Setup toolchain and build artifacts
./pf.py build-setup build-build

# Build an ESP containing the ISO
ISO_PATH="${ISO_PATH}" ./pf.py build-package-esp-iso

# Ensure Secure Boot shim is the default BOOTX64
./pf.py valid-esp-secure

# Verify and boot in QEMU (headless)
./pf.py verify-esp-robust
./pf.py test-qemu

echo "☠ ISO run completed"
