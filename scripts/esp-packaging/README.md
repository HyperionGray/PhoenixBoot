# ESP Packaging Scripts

Scripts for creating and managing EFI System Partition (ESP) images.

## Main ESP Packaging

- `esp-package.sh` - Main ESP packaging script
- `esp-package-minimal.sh` - Minimal ESP package
- `esp-package-nosudo.sh` - ESP package without sudo
- `esp-package-enroll.sh` - ESP package with key enrollment
- `esp-package-enroll-nosudo.sh` - ESP package with enrollment (no sudo)

## ESP Configuration

- `esp-normalize-secure.sh` - Normalize ESP for SecureBoot
- `esp-add-allowed-hashes.sh` - Add allowed hashes to ESP
- `esp-config-extract.sh` - Extract ESP configuration

## Package Variants

- `package-esp-neg-attest.sh` - Package ESP with negative attestation test
- `package-esp-neg-attest-nosudo.sh` - Negative attestation (no sudo)

## Installation & Deployment

- `install_clean_grub_boot.sh` - Install clean GRUB boot configuration
- `boot-from-esp-iso.sh` - Boot from ESP ISO
- `deploy-esp-iso.sh` - Deploy ESP ISO

## Usage

```bash
# Create ESP package
./pf.py build-package-esp

# Or run script directly
sudo ./scripts/esp-packaging/esp-package.sh
```
