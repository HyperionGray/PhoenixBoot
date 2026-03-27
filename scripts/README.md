# scripts directory

This folder contains host-side helper script entrypoints organized by category. They do not run inside UEFI; they prepare your system or ESP from Linux.

The repository is now organized around component directories under `components/`. The directories under `scripts/` are compatibility symlinks so existing commands such as `bash scripts/testing/qemu-test.sh` keep working while the real script sources live with their owning component.

## Directory Structure

The compatibility entrypoints are organized into the following categories:

### 📦 [build/](build/)
Scripts for building PhoenixBoot artifacts and images.

### 🧪 [testing/](testing/)
Scripts for testing PhoenixBoot functionality using QEMU and other methods.

### 🔑 [mok-management/](mok-management/)
Scripts for managing Machine Owner Keys (MOK) and kernel module signing.

### 💾 [esp-packaging/](esp-packaging/)
Scripts for creating and managing EFI System Partition (ESP) images.

### 🔐 [secure-boot/](secure-boot/)
Scripts for managing SecureBoot keys and enrollment.

### ✅ [validation/](validation/)
Scripts for validating system security and detecting threats.

### 🚑 [recovery/](recovery/)
Scripts for system recovery and remediation.

### 💿 [usb-tools/](usb-tools/)
Scripts for creating and managing bootable USB media.

### 🖥️ [qemu/](qemu/)
Scripts for running QEMU virtual machines.

### 🔧 [uefi-tools/](uefi-tools/)
Scripts for UEFI operations and diagnostics.

### 🛠️ [maintenance/](maintenance/)
Scripts for project maintenance and development.

## Usage

Most scripts require root privileges when writing to the ESP. Scripts are typically accessed through the task runner (`./pf.py <task>`) rather than directly.

Example:
```bash
# Via task runner (recommended)
./pf.py test-qemu
./pf.py secure-keygen
./pf.py build-package-esp

# Direct execution
sudo ./scripts/secure-boot/generate-sb-keys.sh
bash ./scripts/testing/qemu-test.sh
```

Actual script sources now live in:

- `components/core/scripts/`
- `components/secure/scripts/`
- `components/workflows/scripts/`
- `components/maint/scripts/`

See individual category README files for detailed information about each script.
