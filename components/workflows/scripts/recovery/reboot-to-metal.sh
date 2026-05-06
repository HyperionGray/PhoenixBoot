#!/bin/bash
# reboot-to-metal.sh - Reboot back to Normal Metal Operation
# This restores the original bootloader, cleans up ESP staging, and reboots

set -euo pipefail

if ! command -v efibootmgr >/dev/null 2>&1; then
    echo "ERROR: efibootmgr is required for safe cleanup."
    exit 1
fi

echo "☠ Restoring system to normal boot operation..."
echo "☠ Risk Level: MEDIUM"
echo "   Most likely: PhoenixGuard recovery entries will be removed and the system will reboot normally."
echo "   Could happen: Manual UEFI cleanup may still be needed if recovery entries were duplicated earlier."
echo "   Worst case: If no non-PhoenixGuard boot entry exists, rebooting now could leave the system without an obvious boot target."
echo "The system will reboot automatically in 5 seconds. Press Ctrl+C to cancel."
sleep 5 || exit 0

echo "☠ Cleaning up PhoenixGuard recovery environment..."

TS=$(date +%F_%H%M%S)
BACKUP_DIR="/var/lib/phoenixguard/backups/$TS"
sudo mkdir -p "$BACKUP_DIR"
sudo efibootmgr -v | sudo tee "$BACKUP_DIR/efibootmgr-before-metal.txt" >/dev/null

NON_PHOENIX_ENTRIES=$(efibootmgr | awk '/^Boot[0-9A-Fa-f]{4}\*/ && $0 !~ /PhoenixGuard/')
if [[ -z "$NON_PHOENIX_ENTRIES" ]]; then
    echo "ERROR: No non-PhoenixGuard boot entries were found."
    echo "       Refusing cleanup because automatic reboot could leave the system without a normal boot target."
    echo "       Review $BACKUP_DIR/efibootmgr-before-metal.txt before making changes."
    exit 1
fi

# Remove PhoenixGuard boot entries
echo "[uefi] Removing PhoenixGuard boot entries"
BOOTNUMS=$(efibootmgr | awk -F'*' '/PhoenixGuard/{print $1}' | sed 's/Boot//;s/\s*$//')
for num in $BOOTNUMS; do
    if [[ -n "$num" ]]; then
        sudo efibootmgr -b "$num" -B >/dev/null || true
    fi
done

# Clean up ESP staging
echo "[esp] Cleaning up ESP staging"
ESP=$(findmnt -t vfat -n -o TARGET | head -n1 || true)
if [[ -z "$ESP" ]]; then
    ESP="/boot/efi"
fi

if [[ -d "$ESP/EFI/PhoenixGuard" ]]; then
    sudo rm -rf "$ESP/EFI/PhoenixGuard" || true
fi

# Remove KVM recovery configuration
echo "[cleanup] Removing KVM recovery configuration"
sudo rm -f /etc/phoenixguard/kvm-snapshot.conf || true
sudo systemctl disable kvm-snapshot-jump.service >/dev/null 2>&1 || true
sudo systemctl disable pg-remediate.service >/dev/null 2>&1 || true

# Remove GRUB recovery entries
echo "[grub] Removing GRUB recovery entries"
sudo rm -f /etc/grub.d/42_phoenixguard_recovery || true
sudo update-grub >/dev/null 2>&1 || true
sudo efibootmgr -v | sudo tee "$BACKUP_DIR/efibootmgr-after-metal.txt" >/dev/null

echo "☠ Removed: PhoenixGuard UEFI boot entries"
echo "☠ Cleaned: ESP staging at $ESP/EFI/PhoenixGuard/"
echo "☠ Disabled: KVM recovery services"
echo "☠ Backup saved: $BACKUP_DIR"
echo
echo "☠ System ready to reboot to normal operation"
echo "   Your original bootloader should now be restored"

sudo reboot
