#!/usr/bin/env bash
# Add firmware to checksum database (set FIRMWARE_PATH, VENDOR, MODEL, VERSION)
[ -n "${FIRMWARE_PATH:-}" ] || { echo "Usage: FIRMWARE_PATH=<file> VENDOR=<vendor> MODEL=<model> VERSION=<version> ./pf.py firmware-checksum-add"; exit 1; }
[ -n "${VENDOR:-}" ] && [ -n "${MODEL:-}" ] && [ -n "${VERSION:-}" ] || { echo "Error: VENDOR, MODEL, and VERSION are required"; exit 1; }
${PYTHON:-python3} utils/firmware_checksum_db.py --add "${FIRMWARE_PATH}" --vendor "${VENDOR}" --model "${MODEL}" --version "${VERSION}" --source "${SOURCE:-manual}" --confidence ${CONFIDENCE:-50}
