# 🚀 Getting Started with PhoenixBoot

Welcome to PhoenixBoot! This guide will help you get started quickly and understand what PhoenixBoot can do for you.

## What is PhoenixBoot?

PhoenixBoot (also known as PhoenixGuard) is a secure boot defense system that helps protect your computer from:
- 🛡️ **Bootkits** - Malware that infects your boot process
- 🔐 **Rootkits** - Hidden malware in your system
- 📦 **Supply chain attacks** - Compromised firmware or software
- 🔓 **Unauthorized boot modifications** - Tampering with your boot process

## Quick Start Options

### Option 1: Create SecureBoot Bootable Media (Easiest!) 🎯

This is the **fastest and easiest** way to get started if you want to create a SecureBoot-enabled USB or CD from an ISO:

```bash
# One command writes the ISO to your USB drive (DESTRUCTIVE):
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso --usb-device /dev/sdX
# (or: ./pf.py secureboot-create iso_path=/path/to/ubuntu.iso usb_device=/dev/sdX  # alias secureboot-create-usb)
```

✅ **What this does:**
- (Optional) generates SecureBoot keys (PK, KEK, db) + enrollment files (.auth)
- Writes the ISO directly to the USB drive you choose
- Runs a size preflight check and prompts before erasing the device

📖 **Learn more**: [SecureBoot Bootable Media Guide](docs/SECUREBOOT_BOOTABLE_MEDIA.md)

### Option 2: Interactive TUI (User-Friendly!) 🎨

If you prefer a graphical interface, use the Terminal User Interface:

```bash
# Launch the interactive TUI
./phoenixboot-tui.sh

# Or via containers
docker-compose --profile tui up
```

✅ **What you get:**
- Organized task categories
- One-click task execution
- Real-time output display
- Modern, intuitive interface

📖 **Learn more**: [TUI Guide](docs/TUI_GUIDE.md)

### Option 3: Command Line Tasks 💻

For advanced users who prefer the command line:

```bash
# List all available tasks
./pf.py list

# Run specific tasks
./pf.py secure-keygen    # Generate SecureBoot keys
./pf.py test-qemu        # Test in QEMU
./pf.py secure-env       # Check system security
```

## What Can PhoenixBoot Do?

### 1. 🔐 SecureBoot Key Management

Generate your own SecureBoot keys and enroll them on your system:

```bash
# Generate keys
./pf.py secure-keygen

# Your keys will be in keys/ and out/keys/
# Keys include: PK (Platform Key), KEK (Key Exchange Key), db (Signature Database)
```

**Use case**: Take control of your boot security instead of trusting only manufacturer keys.

### 2. ✍️ Kernel Module Signing

Sign kernel modules so they work with SecureBoot enabled:

```bash
# Easy way (for all users)
./sign-kernel-modules.sh

# Via task runner
MODULE_PATH=/path/to/module.ko ./pf.py os-kmod-sign
```

**Use case**: Install drivers (like `apfs.ko` for Mac filesystems) on a SecureBoot system.

### 3. 🔍 Security Environment Check

Scan your system for security issues:

```bash
./pf.py secure-env
```

**What it checks:**
- EFI variables for tampering
- Boot integrity (bootloader, kernel, initramfs)
- SecureBoot status
- Kernel security features
- Bootkit detection
- Module signatures

### 4. 🧪 Testing with QEMU

Test your boot configuration safely in a virtual machine:

```bash
./pf.py test-qemu              # Basic boot test
./pf.py test-qemu-secure-positive  # SecureBoot test
./pf.py test-qemu-uuefi        # UEFI diagnostic test
```

### 5. 🛠️ UUEFI - UEFI Diagnostic Tool

Boot into a diagnostic environment to inspect your firmware:

```bash
# Install UUEFI to your ESP
sudo ./scripts/uefi-tools/uuefi-install.sh

# Boot to it once (sets BootNext)
sudo ./scripts/uefi-tools/uuefi-apply.sh
```

**What UUEFI shows:**
- Firmware version and vendor
- Memory information
- SecureBoot status
- Boot configuration
- All UEFI variables with descriptions

## Common Tasks

### Create Bootable SecureBoot USB

```bash
# From an ISO (DESTRUCTIVE)
./create-secureboot-bootable-media.sh --iso /path/to/ubuntu.iso --usb-device /dev/sdX
```

### Sign a Kernel Module

```bash
# Easy way
./sign-kernel-modules.sh

# Manual way
MODULE_PATH=/lib/modules/$(uname -r)/kernel/fs/apfs.ko ./pf.py os-kmod-sign
```

### Check System Security

```bash
./pf.py secure-env
```

### Generate Your Own SecureBoot Keys

```bash
./pf.py secure-keygen

# Keys are created in keys/ and out/keys/
# Use KeyEnrollEdk2.efi to enroll them in BIOS
```

## Directory Structure (Where Things Are)

```
PhoenixBoot/
├── create-secureboot-bootable-media.sh  # 👈 START HERE for bootable media
├── sign-kernel-modules.sh               # 👈 Easy module signing
├── phoenixboot-tui.sh                   # 👈 Interactive interface
├── pf.py                                # Task runner
├── scripts/                             # Organized by category
│   ├── build/                          # Build scripts
│   ├── testing/                        # Test scripts
│   ├── secure-boot/                    # SecureBoot operations
│   ├── validation/                     # Security checks
│   └── ...                             # More categories
├── docs/                               # Comprehensive documentation
├── staging/                            # UEFI applications source
└── out/                                # Build artifacts and results
```

## Getting Help

### Documentation

- **This guide** - You are here! 📍
- [README.md](README.md) - Comprehensive overview
- [QUICKSTART.md](QUICKSTART.md) - Quick command reference
- [docs/](docs/) - Detailed technical documentation

### Common Questions

**Q: Do I need to understand UEFI to use this?**
A: No! Use the easy options (bootable media creator or TUI). Advanced features require more knowledge.

**Q: Will this work on my computer?**
A: PhoenixBoot works on any UEFI-based system (most computers from 2010+). Legacy BIOS is not supported.

**Q: Is this safe to use?**
A: Yes! Start with testing in QEMU. The bootable media creator is safe and won't modify your system.

**Q: Can I break my computer?**
A: The scripts are designed to be safe. However, always backup important data before modifying boot configurations.

### Getting Support

- **GitHub Issues**: [https://github.com/P4X-ng/PhoenixBoot/issues](https://github.com/P4X-ng/PhoenixBoot/issues)
- **Documentation**: Check the [docs/](docs/) directory
- **Examples**: See [examples_and_samples/](examples_and_samples/)

## Next Steps

1. **Try the easy option**: Create bootable media with `./create-secureboot-bootable-media.sh`
2. **Explore the TUI**: Launch `./phoenixboot-tui.sh` for an interactive experience
3. **Check security**: Run `./pf.py secure-env` to see your system status
4. **Read the docs**: Browse [docs/](docs/) for detailed information
5. **Join the project**: Contributions welcome!

## Safety Tips 🛡️

- ✅ **Start with QEMU testing** - Test configurations safely in a VM
- ✅ **Backup your data** - Always have backups before modifying boot
- ✅ **Read the warnings** - Some scripts (like `nuclear-wipe.sh`) are destructive
- ✅ **Use the task runner** - `./pf.py` tasks are safer than running scripts directly
- ✅ **Ask for help** - Open an issue if you're unsure

## Real-World Use Cases

### Scenario 1: New Computer Setup
1. Generate your own SecureBoot keys
2. Create bootable USB with your OS
3. Enroll keys on first boot
4. Install OS with your keys in control

### Scenario 2: Driver Installation
1. Download unsigned driver (like `apfs.ko`)
2. Sign it with your MOK key
3. Load the driver normally
4. SecureBoot remains enabled!

### Scenario 3: Security Audit
1. Run `./pf.py secure-env`
2. Review the security report
3. Fix any issues found
4. Verify with another scan

---

**Made with 🔥 for a more secure boot process**

Need more help? Check out the [comprehensive README](README.md) or browse the [documentation](docs/).
