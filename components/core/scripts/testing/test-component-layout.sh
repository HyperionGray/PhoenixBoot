#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
cd "$PROJECT_ROOT"

components=(core secure workflows maint)
required_dirs=(include src build bin scripts)
script_links=(
  "scripts/build"
  "scripts/testing"
  "scripts/validation"
  "scripts/uefi-tools"
  "scripts/secure-boot"
  "scripts/mok-management"
  "scripts/esp-packaging"
  "scripts/qemu"
  "scripts/recovery"
  "scripts/usb-tools"
  "scripts/maintenance"
  "scripts/git-hooks"
)

for component in "${components[@]}"; do
  for dir in "${required_dirs[@]}"; do
    if [ ! -e "components/${component}/${dir}" ]; then
      echo "Missing components/${component}/${dir}" >&2
      exit 1
    fi
  done

  if [ ! -f "components/${component}/Pfyfile.pf" ]; then
    echo "Missing components/${component}/Pfyfile.pf" >&2
    exit 1
  fi

  if [ ! -e "components/${component}/Makefile" ]; then
    echo "Missing components/${component}/Makefile" >&2
    exit 1
  fi
done

if [ ! -d "includes" ]; then
  echo "Missing top-level includes/" >&2
  exit 1
fi

for link in "${script_links[@]}"; do
  if [ ! -L "$link" ]; then
    echo "Expected compatibility symlink at $link" >&2
    exit 1
  fi
done

if [ ! -f "includes/lib/common.sh" ]; then
  echo "Shared include library layout is incomplete" >&2
  exit 1
fi

if [ -e "scripts/lib" ]; then
  echo "Legacy scripts/lib shim should not exist" >&2
  exit 1
fi

if grep -R -n 'source scripts/lib/common\.sh' \
  components/core/scripts/uefi-tools \
  components/core/scripts/validation \
  components/secure/scripts \
  components/workflows/scripts \
  create-secureboot-bootable-media.sh >/dev/null; then
  echo "Found legacy scripts/lib include paths" >&2
  exit 1
fi

echo "Component layout looks correct"
