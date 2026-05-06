#!/usr/bin/env bash
# PhoenixBoot - Build Production Artifacts
# Builds or copies UEFI applications for production use

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REPO_ROOT="$(git -C "${SCRIPT_DIR}" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         PhoenixBoot - Build Production Artifacts                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo

cd "${REPO_ROOT}"

# Check if we should force rebuild from source
FORCE_BUILD="${PG_FORCE_BUILD:-0}"

# Define artifact locations
STAGING_BOOT="${REPO_ROOT}/staging/boot"
STAGING_SRC="${REPO_ROOT}/staging/src"
BUILD_TOOLS="${REPO_ROOT}/staging/tools"
OUT_STAGING="${REPO_ROOT}/out/staging"

# Required artifacts
REQUIRED_ARTIFACTS=(
    "NuclearBootEdk2.efi"
    "UUEFI.efi"
    "KeyEnrollEdk2.efi"
)

# Check if pre-built artifacts exist
all_artifacts_exist() {
    for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
        if [ ! -f "${STAGING_BOOT}/${artifact}" ]; then
            return 1
        fi
    done
    return 0
}

sync_packaging_artifacts() {
    mkdir -p "${OUT_STAGING}"

    if [ -f "${STAGING_BOOT}/NuclearBootEdk2.efi" ]; then
        cp -f "${STAGING_BOOT}/NuclearBootEdk2.efi" "${OUT_STAGING}/BootX64.efi"
    fi
    if [ -f "${STAGING_BOOT}/KeyEnrollEdk2.efi" ]; then
        cp -f "${STAGING_BOOT}/KeyEnrollEdk2.efi" "${OUT_STAGING}/KeyEnrollEdk2.efi"
    fi
    if [ -f "${STAGING_BOOT}/UUEFI.efi" ]; then
        cp -f "${STAGING_BOOT}/UUEFI.efi" "${OUT_STAGING}/UUEFI.efi"
    fi
}

echo "Checking for pre-built artifacts in staging/boot/..."

if all_artifacts_exist && [ "$FORCE_BUILD" != "1" ]; then
    echo -e "${GREEN}✓ All required artifacts found in staging/boot/${NC}"
    sync_packaging_artifacts
    echo
    echo "Found artifacts:"
    for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
        if [ -f "${STAGING_BOOT}/${artifact}" ]; then
            size=$(stat -c%s "${STAGING_BOOT}/${artifact}" 2>/dev/null || stat -f%z "${STAGING_BOOT}/${artifact}" 2>/dev/null || echo "unknown")
            echo -e "  ${GREEN}✓${NC} ${artifact} (${size} bytes)"
        fi
    done
    echo
    echo "Artifacts are ready for use."
    echo "Packaging artifacts synced to: ${OUT_STAGING}/"
    echo -e "${YELLOW}Note: Set PG_FORCE_BUILD=1 to rebuild from source${NC}"
    exit 0
fi

# If artifacts don't exist or force build is requested
echo -e "${YELLOW}⚠ Building artifacts from source...${NC}"
echo

# Check if EDK2 build tools are available
if [ ! -f "${BUILD_TOOLS}/build-nuclear-boot-edk2.sh" ]; then
    echo -e "${RED}✗ Build script not found: ${BUILD_TOOLS}/build-nuclear-boot-edk2.sh${NC}"
    echo
    echo "Build scripts are missing. Please ensure the repository is complete."
    exit 1
fi

# Build NuclearBootEdk2
echo -e "${BLUE}[1/3] Building NuclearBootEdk2.efi...${NC}"
if [ -d "${STAGING_SRC}" ] && [ -f "${STAGING_SRC}/NuclearBootEdk2.c" ]; then
    cd "${STAGING_SRC}"
    if bash "${BUILD_TOOLS}/build-nuclear-boot-edk2.sh"; then
        echo -e "${GREEN}✓ NuclearBootEdk2.efi built successfully${NC}"
        # Copy to staging/boot if build succeeded
        if [ -f "NuclearBootEdk2.efi" ]; then
            cp -f "NuclearBootEdk2.efi" "${STAGING_BOOT}/"
        fi
    else
        echo -e "${RED}✗ Failed to build NuclearBootEdk2.efi${NC}"
    fi
else
    echo -e "${YELLOW}⚠ NuclearBootEdk2 source not found, skipping${NC}"
fi

# Build UUEFI
echo
echo -e "${BLUE}[2/3] Building UUEFI.efi...${NC}"
if [ -d "${STAGING_SRC}" ] && [ -f "${STAGING_SRC}/UUEFI.c" ]; then
    cd "${STAGING_SRC}"
    if bash "${BUILD_TOOLS}/build-uuefi.sh"; then
        echo -e "${GREEN}✓ UUEFI.efi built successfully${NC}"
        # Copy to staging/boot if build succeeded
        if [ -f "UUEFI.efi" ]; then
            cp -f "UUEFI.efi" "${STAGING_BOOT}/"
        fi
    else
        echo -e "${RED}✗ Failed to build UUEFI.efi${NC}"
    fi
else
    echo -e "${YELLOW}⚠ UUEFI source not found, skipping${NC}"
fi

# Build KeyEnrollEdk2
echo
echo -e "${BLUE}[3/3] Building KeyEnrollEdk2.efi...${NC}"
if [ -d "${STAGING_SRC}" ] && [ -f "${STAGING_SRC}/KeyEnrollEdk2.c" ]; then
    cd "${STAGING_SRC}"
    # Check if there's a build script for KeyEnroll
    if [ -f "${BUILD_TOOLS}/build-keyenroll-edk2.sh" ]; then
        if bash "${BUILD_TOOLS}/build-keyenroll-edk2.sh"; then
            echo -e "${GREEN}✓ KeyEnrollEdk2.efi built successfully${NC}"
            if [ -f "KeyEnrollEdk2.efi" ]; then
                cp -f "KeyEnrollEdk2.efi" "${STAGING_BOOT}/"
            fi
        else
            echo -e "${RED}✗ Failed to build KeyEnrollEdk2.efi${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ KeyEnrollEdk2 build script not found, checking for pre-built version${NC}"
        if [ -f "${STAGING_BOOT}/KeyEnrollEdk2.efi" ]; then
            echo -e "${GREEN}✓ Using pre-built KeyEnrollEdk2.efi${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ KeyEnrollEdk2 source not found, checking for pre-built version${NC}"
    if [ -f "${STAGING_BOOT}/KeyEnrollEdk2.efi" ]; then
        echo -e "${GREEN}✓ Using pre-built KeyEnrollEdk2.efi${NC}"
    fi
fi

cd "${REPO_ROOT}"

# Final check
echo
echo "═══════════════════════════════════════════════════════════════════"
echo "Build Summary:"
echo "═══════════════════════════════════════════════════════════════════"
echo

success_count=0
for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
    if [ -f "${STAGING_BOOT}/${artifact}" ]; then
        size=$(stat -c%s "${STAGING_BOOT}/${artifact}" 2>/dev/null || stat -f%z "${STAGING_BOOT}/${artifact}" 2>/dev/null || echo "unknown")
        echo -e "  ${GREEN}✓${NC} ${artifact} (${size} bytes)"
        success_count=$((success_count + 1))
    else
        echo -e "  ${RED}✗${NC} ${artifact} - MISSING"
    fi
done

echo

if [ "$success_count" -eq "${#REQUIRED_ARTIFACTS[@]}" ]; then
    sync_packaging_artifacts
    echo -e "${GREEN}✅ All artifacts built successfully!${NC}"
    echo
    echo "Artifacts are ready in: ${STAGING_BOOT}/"
    echo "Packaging artifacts synced to: ${OUT_STAGING}/"
    exit 0
else
    echo -e "${YELLOW}⚠ Some artifacts are missing${NC}"
    echo
    echo "Missing artifacts may cause issues with ESP packaging and testing."
    echo "Consider checking the build logs or EDK2 setup."
    exit 1
fi
