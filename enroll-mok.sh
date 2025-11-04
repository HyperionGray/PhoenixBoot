#!/usr/bin/env bash
set -euo pipefail

# Enroll PhoenixGuard MOK (Machine Owner Key) certificate
# Required for signing and loading custom kernel modules with Secure Boot
#
# Usage:
#   ./enroll-mok.sh [CERT_PEM] [CERT_DER] [DRY_RUN]
#
# Arguments:
#   CERT_PEM  - Path to PEM certificate (default: out/keys/mok/PGMOK.crt)
#   CERT_DER  - Path to DER certificate (default: out/keys/mok/PGMOK.der)
#   DRY_RUN   - Set to 1 for dry run (default: 0)
#
# Example:
#   ./enroll-mok.sh                                  # Use defaults
#   ./enroll-mok.sh mycert.crt mycert.der 0          # Custom certificate

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MOK_CERT_PEM="${1:-out/keys/mok/PGMOK.crt}"
MOK_CERT_DER="${2:-out/keys/mok/PGMOK.der}"
MOK_DRY_RUN="${3:-0}"

echo "☠ Enrolling MOK certificate..."
exec bash "${SCRIPT_DIR}/scripts/enroll-mok.sh" "${MOK_CERT_PEM}" "${MOK_CERT_DER}" "${MOK_DRY_RUN}"
