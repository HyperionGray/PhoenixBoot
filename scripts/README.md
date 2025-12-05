# scripts directory

This folder contains host-side helper scripts organized by category. They do not run inside UEFI; they prepare your system or ESP from Linux.

## Directory Structure

The scripts are organized into the following categories:

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

See individual category README files for detailed information about each script.

