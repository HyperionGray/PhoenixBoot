#!/usr/bin/env bash
# Write artifacts to USB drive (DESTRUCTIVE - requires USB_DEVICE)
if [ -z "${USB_DEVICE:-}" ]; then
  echo "ERROR: Set USB_DEVICE=/dev/sdX"
  exit 1
fi

if [ ! -b "${USB_DEVICE}" ]; then
  echo "ERROR: ${USB_DEVICE} is not a block device"
  exit 1
fi

ARTIFACT_DIR=out/artifacts
if [ ! -f "$ARTIFACT_DIR/esp/esp.img" ]; then
  echo "ERROR: ESP image not found. Run workflow-artifact-create first"
  exit 1
fi

sudo umount ${USB_DEVICE}* 2>/dev/null || true

echo "Writing ESP image to ${USB_DEVICE}..."
sudo dd if="$ARTIFACT_DIR/esp/esp.img" of=${USB_DEVICE} bs=4M status=progress

sudo sync

echo "✅ USB drive written successfully"
echo "   Device: ${USB_DEVICE}"
echo '   You can now boot from this USB drive'
