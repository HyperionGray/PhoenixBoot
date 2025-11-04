#!/usr/bin/env bash
set -euo pipefail

# Build production PhoenixBoot artifacts from staging/
# Creates bootable images and packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "☠ Building PhoenixBoot production artifacts..."
exec bash "${SCRIPT_DIR}/scripts/build-production.sh"
