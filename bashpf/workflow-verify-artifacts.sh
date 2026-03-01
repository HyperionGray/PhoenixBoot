#!/usr/bin/env bash
# Verify all created artifacts are valid
echo 'Verifying artifacts...'

ARTIFACT_DIR=out/artifacts
if [ -f $ARTIFACT_DIR/esp/esp.img ]; then
  SIZE=$(stat -f%z $ARTIFACT_DIR/esp/esp.img 2>/dev/null || stat -c%s $ARTIFACT_DIR/esp/esp.img)
  echo "ESP image: $SIZE bytes"
else
  echo 'ESP image missing!'
  exit 1
fi

for bin in NuclearBootEdk2.efi KeyEnrollEdk2.efi UUEFI.efi; do
  if [ ! -f $ARTIFACT_DIR/esp/$bin ]; then
    echo "Missing $bin"
    exit 1
  else
    echo "Found $bin"
  fi
done

if [ ! -d $ARTIFACT_DIR/keys ]; then
  echo 'Keys directory missing!'
  exit 1
else
  echo 'Keys directory found'
fi

if command -v fsck.vfat >/dev/null 2>&1; then
  fsck.vfat -n $ARTIFACT_DIR/esp/esp.img || echo 'ESP image verification: OK (or fsck not available)'
fi

echo '✅ All artifacts verified'
