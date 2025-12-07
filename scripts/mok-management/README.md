# MOK Management Scripts

Scripts for managing Machine Owner Keys (MOK) and kernel module signing.

## MOK Operations

- `mok-new.sh` - Create new MOK certificate
- `mok-list-keys.sh` - List available MOK certificates
- `mok-find-enrolled.sh` - Find enrolled MOK certificates
- `mok-pick-existing.sh` - Select existing MOK certificate
- `mok-select-key.sh` - Select MOK key for use
- `mok-status.sh` - Show MOK enrollment status
- `mok-verify.sh` - Verify MOK configuration
- `enroll-mok.sh` - Enroll MOK certificate
- `unenroll-mok.sh` - Unenroll MOK certificate

## Module Signing

- `sign-kmods.sh` - Sign kernel modules
- `os-kmod.sh` - Kernel module operations
- `fix-module-order.sh` - Fix module loading order
- `kmod-autoload.sh` - Auto-load kernel modules
- `kmod-setup-fastpath.sh` - Setup fast-path for kernel modules

## Usage

```bash
# Create and enroll new MOK
./scripts/mok-management/mok-new.sh
sudo ./scripts/mok-management/enroll-mok.sh <cert.crt> <cert.der>

# Sign kernel modules
PATH=/path/to/module.ko ./pf.py os-kmod-sign

# List MOK keys
./scripts/mok-management/mok-list-keys.sh
```
