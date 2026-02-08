#!/usr/bin/env bash
set -euo pipefail

# PhoenixGuard Kernel Module Signing Tool
# Easy-to-use wrapper for pgmodsign.py
#
# This script signs kernel modules (.ko files) with PhoenixGuard certificates
# for SecureBoot compliance.
#
# Usage:
#   ./sign-kernel-modules.sh module.ko              # Sign single module
#   ./sign-kernel-modules.sh *.ko                   # Sign all .ko files
#   ./sign-kernel-modules.sh --force module.ko      # Re-sign already signed
#
# Options:
#   --cert-path PATH    - Override certificate path
#   --key-path PATH     - Override key path
#   --force, -f         - Re-sign already signed modules
#   --verbose, -v       - Enable verbose logging
#   --help, -h          - Show this help message
# Defaults:
#   Certificate: out/keys/mok/PGMOK.crt
#   Private key: out/keys/mok/PGMOK.key

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show help if requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "PhoenixGuard Kernel Module Signing Tool"
    echo ""
    echo "Usage: $0 [OPTIONS] MODULE_FILES..."
    echo ""
    echo "Examples:"
    echo "  $0 module.ko                    # Sign single module"
    echo "  $0 *.ko                         # Sign all .ko files"
    echo "  $0 --force module.ko            # Re-sign already signed module"
    echo ""
    echo "Options:"
    echo "  --cert-path PATH    Path to signing certificate (PEM)"
    echo "  --key-path PATH     Path to signing private key (PEM)"
    echo "  --force, -f         Force re-signing of already signed modules"
    echo "  --verbose, -v       Verbose logging"
    echo "  --help, -h          Show this help message"
    echo ""
    echo "Default certificate: out/keys/mok/PGMOK.crt"
    echo "Default key:         out/keys/mok/PGMOK.key"
    exit 0
fi

# Check if any arguments provided
if [[ $# -eq 0 ]]; then
    echo "Error: No module files specified"
    echo "Usage: $0 [OPTIONS] MODULE_FILES..."
    echo "Try '$0 --help' for more information"
    exit 1
fi

# Execute pgmodsign.py with all arguments
exec python3 "${SCRIPT_DIR}/utils/pgmodsign.py" "$@"
