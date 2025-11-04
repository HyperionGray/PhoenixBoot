#!/usr/bin/env bash
set -euo pipefail

# Generate Secure Boot keypairs and certificates
# Creates RSA-4096 keys for PK, KEK, and db

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Generating Secure Boot keypairs..."
exec bash "${SCRIPT_DIR}/scripts/generate-sb-keys.sh"
