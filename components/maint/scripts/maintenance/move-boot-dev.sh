#!/usr/bin/env bash
# Description: Move hardware boot development code to experimental/ tree.
#
# This is a one-shot migration helper. The bulk of the work was done during
# the alpha cleanup (see ALPHA_RELEASE_PLAN.md); the experimental tree now
# lives at experimental/. This script remains as a safety net in case anyone
# re-creates the old dev/ layout.
#
# The script is idempotent: if a destination directory already exists, the
# corresponding source directory is left alone (it will not be merged in or
# nested as <dest>/<src>). Globbing for individual scripts uses nullglob so
# empty patterns are skipped cleanly.

set -euo pipefail
shopt -s nullglob

DEST_FW="experimental/firmware-recovery-dev"
DEST_HW="experimental/hardware-database"
DEST_SH="experimental/scraped-hardware"

migrate_scripts() {
    [ -d scripts ] || return 0
    mkdir -p "${DEST_FW}"

    # Build a deduplicated list of files matching any of the legacy globs.
    declare -A seen=()
    local pattern script
    for pattern in scripts/hardware*.py scripts/*flashrom* scripts/*firmware* scripts/fix-*; do
        for script in $pattern; do
            [ -f "$script" ] || continue
            if [ -n "${seen[$script]:-}" ]; then continue; fi
            seen[$script]=1
            if [ -e "${DEST_FW}/$(basename "$script")" ]; then
                echo "skip (already migrated): $script"
                continue
            fi
            mv -- "$script" "${DEST_FW}/"
            echo "moved: $script -> ${DEST_FW}/"
        done
    done
}

migrate_dir() {
    local src="$1" dest="$2"
    [ -d "$src" ] || return 0
    if [ -d "$dest" ]; then
        echo "skip (destination exists): $src -> $dest"
        return 0
    fi
    mv -- "$src" "$dest"
    echo "moved: $src -> $dest"
}

migrate_scripts
migrate_dir hardware_database "${DEST_HW}"
migrate_dir scraped_hardware  "${DEST_SH}"

echo "Hardware boot development code migration complete (target: experimental/)"
