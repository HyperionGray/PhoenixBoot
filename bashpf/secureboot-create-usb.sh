#!/usr/bin/env bash
# Create SecureBoot USB and write directly (set ISO_PATH and USB_DEVICE)
bash create-secureboot-bootable-media.sh --iso "${ISO_PATH}" --usb-device "${USB_DEVICE}"
