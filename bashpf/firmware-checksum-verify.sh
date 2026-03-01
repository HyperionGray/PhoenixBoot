#!/usr/bin/env bash
# Verify firmware file against database (set FIRMWARE_PATH=<path>)
[ -n "${FIRMWARE_PATH:-}" ] || { echo "Usage: FIRMWARE_PATH=<file> ./pf.py firmware-checksum-verify"; exit 1; }
${PYTHON:-python3} utils/firmware_checksum_db.py --verify "${FIRMWARE_PATH}"
