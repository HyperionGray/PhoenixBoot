#!/usr/bin/env bash
# Test UUEFI application in QEMU (requires QEMU, OVMF, mtools)
command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo 'ERROR: qemu-system-x86_64 not found. Install QEMU.'; exit 1; }
command -v mcopy >/dev/null 2>&1 || { echo 'ERROR: mcopy not found. Install mtools.'; exit 1; }

if [ ! -f out/esp/esp.img ]; then
  echo 'Building ESP image...'
  ./pf.py build-package-esp
fi

if [ ! -f staging/boot/UUEFI.efi ]; then
  echo 'ERROR: UUEFI.efi not found'
  exit 1
fi

./pf.py test-qemu-uuefi

echo ''
echo 'Test results:'
if [ -f out/qemu/serial-uuefi.log ]; then
  echo '  Log: out/qemu/serial-uuefi.log'
  wc -l out/qemu/serial-uuefi.log
else
  echo '  No log file generated'
fi

if [ -f out/qemu/report-uuefi.xml ]; then
  echo '  Report: out/qemu/report-uuefi.xml'
  grep -o 'failures="[0-9]*"' out/qemu/report-uuefi.xml
fi
