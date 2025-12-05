# scripts directory

This folder contains host-side helper scripts. They do not run inside UEFI; they prepare your system or ESP from Linux.

Key scripts
- install_clean_grub_boot.sh: Stage shim/grub and a minimal grub.cfg under EFI/PhoenixGuard on the ESP.
  Example:
    sudo ./scripts/install_clean_grub_boot.sh --esp /boot/efi --root-uuid <UUID>

Notes
- These scripts require root privileges when writing to the ESP.

