#!/usr/bin/env bash
# Prepare bootable CD/ISO with ESP and secure boot artifacts
ARTIFACT_DIR=out/artifacts
if [ ! -d "$ARTIFACT_DIR/esp" ]; then
  echo 'Run workflow-artifact-create first'
  exit 1
fi

CD_BUILD_DIR=nuclear-cd-build
mkdir -p "$CD_BUILD_DIR/boot" "$CD_BUILD_DIR/efi" "$CD_BUILD_DIR/keys"

if [ -f "$ARTIFACT_DIR/esp/esp.img" ]; then
  cp "$ARTIFACT_DIR/esp/esp.img" "$CD_BUILD_DIR/boot/"
fi

cp "$ARTIFACT_DIR/esp/"*.efi "$CD_BUILD_DIR/efi/" || true

if [ -d "$ARTIFACT_DIR/keys" ]; then
  cp -r "$ARTIFACT_DIR/keys/"* "$CD_BUILD_DIR/keys/" || true
fi

bash scripts/secure-boot/create-secureboot-instructions.sh

echo '✅ CD structure prepared in' "$CD_BUILD_DIR"
echo '   Next: Use ISO creation tool to burn to CD'
