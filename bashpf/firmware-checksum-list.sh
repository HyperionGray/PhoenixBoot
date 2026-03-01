#!/usr/bin/env bash
# List all firmware checksums in database
${PYTHON:-python3} utils/firmware_checksum_db.py --list
