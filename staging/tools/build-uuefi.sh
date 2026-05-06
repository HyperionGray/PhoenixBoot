#!/bin/bash
#
# Build UUEFI EDK2 Application
# Simple diagnostic UEFI application
#

set -euo pipefail

# Store original directory at the very beginning
ORIG_DIR=$(pwd)

echo "🔥 Building UUEFI - Universal UEFI Diagnostic Application 🔥"
echo "============================================================"

# Check if we're in the right directory
if [ ! -f "UUEFI.c" ] || [ ! -f "UUEFI.inf" ]; then
  echo "ERROR: UUEFI source files not found"
  echo "Run this script from the directory containing UUEFI.c"
  exit 1
fi

for tool in git make gcc nasm python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: required EDK2 build tool not found: $tool"
    exit 1
  fi
done

TOOLCHAIN_TAG="${EDK2_TOOLCHAIN_TAG:-GCC}"

# Check for EDK2 setup
if [ -z "${EDK_TOOLS_PATH:-}" ]; then
  echo "Setting up EDK2 environment..."

  # Try to find EDK2 in common locations
  if [ -d "/opt/edk2" ]; then
    export WORKSPACE="/opt/edk2"
  elif [ -d "$HOME/edk2" ]; then
    export WORKSPACE="$HOME/edk2"
  elif [ -d "../../../edk2" ]; then
    export WORKSPACE="$(pwd)/../../../edk2"
  else
    echo "EDK2 not found — cloning to $HOME/edk2 ..."
    git clone --depth=1 https://github.com/tianocore/edk2 "$HOME/edk2"
    export WORKSPACE="$HOME/edk2"
  fi

  echo "Using EDK2 workspace: $WORKSPACE"

  if [ -f "$WORKSPACE/edksetup.sh" ]; then
    cd "$WORKSPACE"
    # Initialize submodules
    git submodule update --init --depth=1 || true
    # Build BaseTools if missing
    NPROC="${NPROC:-$(nproc 2>/dev/null || echo 2)}"
    if ! make -C BaseTools -j"$NPROC"; then
      echo "Parallel build failed, trying sequential build..."
      make -C BaseTools
    fi
    # Ensure Python is set for edksetup.sh
    export PYTHON_COMMAND=${PYTHON_COMMAND:-python3}
    # Temporarily relax 'set -u' for edksetup.sh
    set +u
    source edksetup.sh
    set -u
    cd -
  else
    echo "ERROR: EDK2 setup script not found at $WORKSPACE/edksetup.sh"
    exit 1
  fi
fi

# Create application directory in EDK2 workspace
APP_DIR="$WORKSPACE/PhoenixGuardPkg/Application/UUEFI"
echo "Creating application directory: $APP_DIR"
mkdir -p "$APP_DIR"

# Copy source files to EDK2 workspace
echo "Copying source files..."
cp UUEFI.c "$APP_DIR/"
cp UUEFI.inf "$APP_DIR/"

# Create package DSC file if it doesn't exist
PKG_DIR="$WORKSPACE/PhoenixGuardPkg"
DSC_FILE="$PKG_DIR/PhoenixGuardPkg.dsc"

if [ ! -f "$DSC_FILE" ]; then
  echo "Creating PhoenixGuard package DSC file..."
  mkdir -p "$PKG_DIR"

  cat >"$DSC_FILE" <<'EOF'
[Defines]
  PLATFORM_NAME                  = PhoenixGuardPkg
  PLATFORM_GUID                  = 87654321-4321-4321-4321-210987654321
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION               = 0x00010006
  OUTPUT_DIRECTORY                = Build/PhoenixGuardPkg
  SUPPORTED_ARCHITECTURES         = X64
  BUILD_TARGETS                   = DEBUG|RELEASE
  SKUID_IDENTIFIER                = DEFAULT

[LibraryClasses]
  UefiApplicationEntryPoint|MdePkg/Library/UefiApplicationEntryPoint/UefiApplicationEntryPoint.inf
  UefiLib|MdePkg/Library/UefiLib/UefiLib.inf
  DebugLib|MdePkg/Library/BaseDebugLibNull/BaseDebugLibNull.inf
  BaseMemoryLib|MdePkg/Library/BaseMemoryLib/BaseMemoryLib.inf
  MemoryAllocationLib|MdePkg/Library/UefiMemoryAllocationLib/UefiMemoryAllocationLib.inf
  PrintLib|MdePkg/Library/BasePrintLib/BasePrintLib.inf
  PcdLib|MdePkg/Library/BasePcdLibNull/BasePcdLibNull.inf
  BaseLib|MdePkg/Library/BaseLib/BaseLib.inf
  UefiBootServicesTableLib|MdePkg/Library/UefiBootServicesTableLib/UefiBootServicesTableLib.inf
  UefiRuntimeServicesTableLib|MdePkg/Library/UefiRuntimeServicesTableLib/UefiRuntimeServicesTableLib.inf
  DevicePathLib|MdePkg/Library/UefiDevicePathLib/UefiDevicePathLib.inf
  
[Components]
  PhoenixGuardPkg/Application/UUEFI/UUEFI.inf

[PcdsFixedAtBuild]

[PcdsDynamicDefault]
EOF
  echo "✅ Created $DSC_FILE"
else
  # Add UUEFI to existing DSC if not present
  if ! grep -q "UUEFI/UUEFI.inf" "$DSC_FILE" 2>/dev/null; then
    echo "Adding UUEFI to DSC components..."
    sed -i '/\[Components\]/a \\  PhoenixGuardPkg/Application/UUEFI/UUEFI.inf' "$DSC_FILE" || true
  fi
fi

# Create package DEC file if it doesn't exist
DEC_FILE="$PKG_DIR/PhoenixGuardPkg.dec"

if [ ! -f "$DEC_FILE" ]; then
  echo "Creating PhoenixGuard package DEC file..."

  cat >"$DEC_FILE" <<'EOF'
[Defines]
  DEC_SPECIFICATION              = 0x00010006
  PACKAGE_NAME                   = PhoenixGuardPkg
  PACKAGE_GUID                   = 87654321-4321-4321-4321-210987654321
  PACKAGE_VERSION                = 0.1

[Includes]
  Include

[LibraryClasses]

[Guids]

[Protocols]

[PcdsFixedAtBuild]

[PcdsDynamic]
EOF
  echo "✅ Created $DEC_FILE"
fi

# Build the application
echo ""
echo "🔨 Building UUEFI application..."
echo "================================"

cd "$WORKSPACE"

# Build command for X64 architecture
echo "Using EDK2 toolchain tag: $TOOLCHAIN_TAG"
build -p PhoenixGuardPkg/PhoenixGuardPkg.dsc -a X64 -t "$TOOLCHAIN_TAG" -b RELEASE

BUILD_STATUS=$?

if [ $BUILD_STATUS -eq 0 ]; then
  echo ""
  echo "🎉 BUILD SUCCESSFUL! 🎉"
  echo "======================="

  # Find the built EFI file
  EFI_FILE=$(find Build/ -name "UUEFI.efi" 2>/dev/null | head -1)

  if [ -n "$EFI_FILE" ]; then
    echo "✅ UUEFI EFI application: $WORKSPACE/$EFI_FILE"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Copy to EFI System Partition: cp $EFI_FILE /boot/efi/EFI/PhoenixGuard/"
    echo "   2. Or test with QEMU"

    # Copy back to current directory for convenience
    cp "$WORKSPACE/$EFI_FILE" "$ORIG_DIR/UUEFI.efi"
    echo "✅ Copied EFI file to current directory: UUEFI.efi"
    # Also sync to staging/boot for packaging paths
    mkdir -p "$ORIG_DIR/../boot"
    cp "$WORKSPACE/$EFI_FILE" "$ORIG_DIR/../boot/UUEFI.efi" || true

  else
    echo "⚠️  UUEFI.efi not found in build output"
  fi

  echo ""
  echo "🔥 UUEFI build complete!"

else
  echo ""
  echo "❌ BUILD FAILED!"
  echo "==============="
  echo "Check the build log above for errors"
  exit 1
fi
