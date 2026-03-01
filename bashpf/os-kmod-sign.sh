#!/usr/bin/env bash
# Sign one module file or recursively sign directory (set PATH, FORCE=1 optional)
[ -n "${PATH:-}" ] || { echo "Usage: PATH=<file|dir> [FORCE=1] ./pf.py os-kmod-sign"; exit 1; }
"${PYTHON:-python3}" utils/pgmodsign.py "${PATH}" $([ "${FORCE:-0}" = "1" ] && printf -- "--force" || true)
