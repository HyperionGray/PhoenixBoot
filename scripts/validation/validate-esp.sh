#!/usr/bin/env bash
# Description: Validates the contents of the ESP image.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
    cat <<'EOF'
Usage: validate-esp.sh [--image /path/to/esp.img]

Options:
  -i, --image PATH    Specify an alternate ESP image to validate
  -h, --help          Show this message
EOF
    exit 1
}

IMAGE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--image)
            IMAGE="${2:-}"
            shift 2
            ;;
        --image=*)
            IMAGE="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

find_esp_image() {
    local candidate

    if [ -n "$IMAGE" ]; then
        if [ -f "$IMAGE" ]; then
            printf '%s' "$IMAGE"
            return 0
        fi
        echo "☠ Specified ESP image not found: $IMAGE" >&2
        return 1
    fi

    local -a search_paths=()
    if [ -n "${ESP_IMG:-}" ]; then
        search_paths+=("${ESP_IMG}")
    fi
    search_paths+=(
        "out/esp/esp.img"
        "out/esp/enroll-esp.img"
    )

    for candidate in "${search_paths[@]}"; do
        [ -n "$candidate" ] || continue
        if [ -f "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done

    return 1
}

IMG=$(find_esp_image)
[ -n "$IMG" ] || { echo "☠ Missing ESP image; run './pf.py build-package-esp' (or './pf.py secure-package-esp-enroll') first"; exit 1; }
FAIL=0

echo "☠ Listing ESP root:"
mdir -i "$IMG" ::/ || true
echo "☠ Listing EFI/BOOT:"
mdir -i "$IMG" ::/EFI/BOOT || true
echo "☠ Listing EFI/PhoenixGuard:"
mdir -i "$IMG" ::/EFI/PhoenixGuard || true

for f in "/EFI/BOOT/BOOTX64.EFI" "/EFI/PhoenixGuard/NuclearBootEdk2.sha256"; do
    if mtype -i "$IMG" ::$f >/dev/null 2>&1; then
        echo "☠ Present: $f"
    else
        echo "☠ Missing: $f"
        FAIL=1
    fi
done

exit $FAIL
