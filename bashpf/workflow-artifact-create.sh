#!/usr/bin/env bash
# Create all necessary artifacts for ESP and CD with secure boot support
ARTIFACT_DIR=out/artifacts
ESP_DIR=out/esp
KEYS_DIR=out/keys
mkdir -p $ARTIFACT_DIR/esp $ARTIFACT_DIR/cd $ARTIFACT_DIR/docs $ESP_DIR $KEYS_DIR

if [ ! -f staging/boot/NuclearBootEdk2.efi ] || [ ! -f staging/boot/UUEFI.efi ]; then
  ./pf.py build-build
fi

if [ ! -f $KEYS_DIR/PK/PK.key ]; then
  ./pf.py secure-keygen
fi

if [ ! -f $KEYS_DIR/PK/PK.auth ]; then
  ./pf.py secure-make-auth
fi

./pf.py build-package-esp

if [ -f out/esp/esp.img ]; then
  cp out/esp/esp.img $ARTIFACT_DIR/esp/
fi

cp staging/boot/NuclearBootEdk2.efi $ARTIFACT_DIR/esp/
cp staging/boot/KeyEnrollEdk2.efi $ARTIFACT_DIR/esp/
cp staging/boot/UUEFI.efi $ARTIFACT_DIR/esp/

if [ -d $KEYS_DIR ]; then
  cp -r $KEYS_DIR $ARTIFACT_DIR/
fi

echo '✅ Artifacts created in' $ARTIFACT_DIR
ls -lh $ARTIFACT_DIR/esp/
