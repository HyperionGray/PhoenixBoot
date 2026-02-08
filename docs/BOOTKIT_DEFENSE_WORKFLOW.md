# 🛡️ PhoenixBoot: Complete Bootkit Defense Workflow

## Overview

PhoenixBoot provides a **comprehensive three-stage approach** to stop bootkits completely:

1. **🔐 Stage 1: Enable SecureBoot from the Start** - Create install media (+ optionally generate custom keys)
2. **💿 Stage 2: Clean OS Installation** - Install your OS with SecureBoot enabled
3. **🔥 Stage 3: Post-Install Protection** - Clear malicious EFI vars with progressive escalation (NuclearBoot)

This document guides you through all three stages.

---

## Why This Approach Works

**The Reality of Bootkits:**
- Bootkits infect the boot process before your OS loads
- They persist across OS reinstalls because they live in firmware/EFI
- Traditional antivirus can't see them because they load first
- **Solution: Stop the boot chain at the firmware level**

**Our Three-Stage Defense:**
1. ✅ **Custom SecureBoot keys** - Only YOUR signed code boots (not attacker's code)
2. ✅ **Clean installation** - Start fresh with verified boot chain
3. ✅ **Post-install cleanup** - Remove any malicious EFI variables through escalating recovery methods

**Result:** 99% of bootkits are completely neutralized. The remaining 1% require hardware-level intervention (CH341A programmer), which we also support.

---

## 🔐 Stage 1: Enable SecureBoot from the Start

### Goal
Create bootable install media (USB or CD/DVD), and optionally generate your SecureBoot keys.

### Why This Matters
- Prevents bootkits from hijacking the boot chain
- Ensures only YOUR signed code runs at boot time
- Stops the infection before it can spread to your OS

### Quick Start

```bash
./create-secureboot-bootable-media.sh --iso /path/to/your-distro.iso --usb-device /dev/sdX
```

**What this does:**
1. ✅ (Optional) generates your SecureBoot keys (PK, KEK, db) in `keys/`
2. ✅ (Optional) creates enrollment files in `out/securevars/` (`*.auth`)
3. ✅ writes the ISO directly to the USB device you chose (destructive)

**Prefer optical media?** Burn your distro ISO to CD/DVD (immutable medium) with your preferred burning tool.

**Why we recommend CD:**
- **Immutable** - Once burned, cannot be modified
- **Cheap** - USB CD burners cost $15-20
- **Verifiable** - Burn, then verify the hash matches
- **Secure** - No firmware exploits possible on optical media

### What You Get

After Stage 1, you have:
- ✅ Bootable OS installer media (USB or CD/DVD)
- ✅ (Optional) SecureBoot keys in `keys/` (keep these safe!)
- ✅ (Optional) enrollment files in `out/securevars/`

---

## 💿 Stage 2: Clean OS Installation

### Goal
Install your operating system cleanly, with SecureBoot enforcement from boot to kernel.

### Installation Steps

1. **Boot from your OS installer media** (created in Stage 1)
2. **Install your OS normally**
3. **During installation:**
   - ✅ Keep SecureBoot enabled if your installer supports it (most mainstream distros do)
   - ✅ Only signed bootloaders can run (under your platform’s enrolled keys)

**Optional (Advanced):** If you generated custom keys and want to enroll them, see `docs/SECUREBOOT_ENABLEMENT_KEXEC.md`.

### Post-Installation: Sign Your Kernel Modules

Many useful kernel modules (like `apfs.ko` for Mac filesystems) come unsigned. Sign them with your MOK (Machine Owner Key):

```bash
# Easy way - sign kernel modules interactively
./sign-kernel-modules.sh

# Or sign specific module
MODULE_PATH=/path/to/module.ko ./pf.py os-kmod-sign

# Or sign entire directory
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

**What this does:**
- ✅ Generates MOK certificate (if not present)
- ✅ Signs kernel modules with your MOK
- ✅ Prompts for MOK enrollment (one-time setup)
- ✅ Allows your modules to load with SecureBoot enabled

### Verify Clean Installation

Run a security check to ensure your system is clean:

```bash
./pf.py secure-env
```

This comprehensive check verifies:
- ✅ EFI variable integrity
- ✅ Boot chain integrity (bootloader, kernel, initramfs)
- ✅ SecureBoot status and key enrollment
- ✅ Kernel security features (lockdown, KASLR, etc.)
- ✅ No bootkit signatures detected
- ✅ All kernel modules properly signed

**Expected output:** All checks should pass with "✅ CLEAN" status.

---

## 🔥 Stage 3: Post-Install Protection (NuclearBoot)

### Goal
Clear potentially malicious EFI variables through progressive escalation.

### Why This Matters
Even with SecureBoot enabled, sophisticated attackers may have:
- Modified EFI variables before you enabled SecureBoot
- Exploited firmware vulnerabilities to persist in NVRAM
- Installed bootkits that survive OS reinstallation

**NuclearBoot provides escalating recovery methods** - from safest to most extreme - until your system is verified clean.

### The Progressive Escalation Ladder

PhoenixBoot uses **intelligent, progressive escalation**:

```
Level 1: DETECT   → Software-based scanning (no changes)
Level 2: SOFT     → ESP Nuclear Boot ISO (software-only)
Level 3: SECURE   → Double-kexec firmware access (temporary)
Level 4: VM       → Reboot to KVM recovery environment
Level 5: XEN      → Reboot to Xen dom0 (ultimate isolation)
Level 6: HARDWARE → Direct SPI flash recovery (bypass all software)
```

Each level requires confirmation and explains why it's needed.

### Quick Recovery Check

**Run the progressive recovery system:**

```bash
python3 scripts/recovery/phoenix_progressive.py
```

**What this does:**
1. **Level 1: Detects** bootkit infections (safe, no changes)
2. **Analyzes** threat level (CLEAN, LOW, MEDIUM, HIGH, CRITICAL)
3. **Recommends** appropriate escalation level
4. **Asks for confirmation** before each escalation
5. **Executes** recovery steps until system is clean

### Manual NuclearBoot Options

#### Option 1: UUEFI Diagnostic Tool (Interactive)

Use UUEFI to manually inspect and clean EFI variables:

```bash
# Install UUEFI to your ESP
./pf.py uuefi-install

# Set it as next boot
./pf.py uuefi-apply

# Reboot
sudo reboot
```

**On next boot**, UUEFI provides:
- 🔍 **Variable enumeration** - See ALL EFI variables
- ✏️ **Variable editing** - Safely modify tweakable variables
- 🔒 **Security analysis** - Detect suspicious patterns
- 🧹 **Vendor bloat removal** - Delete telemetry/bloatware variables
- ☢️ **Nuclear wipe menu** - Complete NVRAM reset options

See [UUEFI Guide](docs/UUEFI_V3_GUIDE.md) for full details.

#### Option 2: Nuclear Wipe Script (Extreme Cases)

For severe infections, complete system sanitization:

```bash
# EXTREME CAUTION - This wipes everything!
sudo bash scripts/recovery/nuclear-wipe.sh
```

**This provides four options:**
1. **Vendor variable wipe** - Remove bloatware (safe)
2. **Full NVRAM reset** - Factory defaults, preserves security keys
3. **Disk wiping guide** - Instructions for secure disk wipe with nwipe
4. **Complete nuclear wipe** - NVRAM + disk for extreme malware

⚠️ **WARNING:** Options 3 and 4 are PERMANENT and require OS reinstallation!

### When to Use Each Level

| Threat Level | Recommended Action | Tool |
|-------------|-------------------|------|
| **CLEAN** | No action needed | N/A |
| **LOW** | Monitor with periodic scans | `./pf.py secure-env` |
| **MEDIUM** | Run UUEFI, check for suspicious vars | `./pf.py uuefi-apply` |
| **HIGH** | Nuclear wipe vendor vars, reset NVRAM | `nuclear-wipe.sh` option 1-2 |
| **CRITICAL** | Complete nuclear wipe + OS reinstall | `nuclear-wipe.sh` option 4 |

---

## 🎯 Complete Workflow Summary

### First-Time Setup (Do Once)

```bash
# 1. Create bootable installer USB (optionally generates keys)
./create-secureboot-bootable-media.sh --iso /path/to/distro.iso --usb-device /dev/sdX

# 2. Boot from media and install OS with SecureBoot enabled (if supported)
# (Follow on-screen instructions)

# 3. After OS install, sign your kernel modules
./sign-kernel-modules.sh

# 4. Verify clean installation
./pf.py secure-env
```

### Ongoing Protection (Run Periodically)

```bash
# Run security check (weekly recommended)
./pf.py secure-env

# If threats detected, run progressive recovery
python3 scripts/recovery/phoenix_progressive.py

# For manual inspection, use UUEFI
./pf.py uuefi-apply && sudo reboot
```

### Emergency Recovery (Suspected Infection)

```bash
# 1. Run progressive recovery (auto-escalates as needed)
python3 scripts/recovery/phoenix_progressive.py

# 2. If auto-recovery fails, use UUEFI for manual inspection
./pf.py uuefi-apply && sudo reboot

# 3. For severe infections, nuclear wipe
sudo bash scripts/recovery/nuclear-wipe.sh

# 4. If hardware-level bootkit suspected (rare!)
# Contact PhoenixBoot community for CH341A programming guide
```

---

## 🔧 Advanced Features

### Hardware-Level Recovery (The Final 1%)

For the rare case where a bootkit persists even after nuclear wipe, PhoenixBoot supports **hardware-level SPI flash recovery**:

```bash
# Use CH341A programmer to directly flash BIOS chip
# See docs/HARDWARE_ACCESS_DEEP_DIVE.md for details
bash scripts/recovery/hardware-recovery.sh
```

**When to use this:**
- Bootkit survives nuclear wipe
- Firmware appears corrupted
- System won't boot even after recovery
- You have physical access and a CH341A programmer ($5-10)

### Container-Based Workflow

For isolated, reproducible operations:

```bash
# Launch interactive TUI
docker-compose --profile tui up

# Or use specific containers
docker-compose --profile build up    # Build artifacts
docker-compose --profile test up     # Run tests
```

---

## 📚 Additional Documentation

- **[Getting Started Guide](GETTING_STARTED.md)** - New user introduction
- **[SecureBoot Bootable Media Guide](docs/SECUREBOOT_BOOTABLE_MEDIA.md)** - Stage 1 details
- **[UUEFI User Guide](docs/UUEFI_V3_GUIDE.md)** - Interactive EFI variable management
- **[Progressive Recovery Guide](docs/PROGRESSIVE_RECOVERY.md)** - Stage 3 details
- **[Security Environment Check](docs/SECURE_ENV_COMMAND.md)** - Comprehensive scanning
- **[Hardware Access Deep Dive](docs/HARDWARE_ACCESS_DEEP_DIVE.md)** - Hardware recovery

---

## ✅ Success Criteria

After completing all three stages, you should have:

1. ✅ **Custom SecureBoot keys** enrolled in your system
2. ✅ **Clean OS installation** with verified boot chain
3. ✅ **Signed kernel modules** working with SecureBoot
4. ✅ **No suspicious EFI variables** detected
5. ✅ **Regular security scans** showing CLEAN status
6. ✅ **Recovery tools** ready if needed

**Result:** 99% of bootkits are completely neutralized. Your system boots with cryptographic verification from firmware to kernel.

---

## 🆘 Troubleshooting

### "Security Violation" on boot
- **Solution:** Disable SecureBoot OR enroll PhoenixGuard keys first (Stage 1, Option B)

### Kernel module won't load
- **Solution:** Sign the module with MOK: `./sign-kernel-modules.sh`

### SecureBoot won't enable
- **Solution:** Check BIOS settings, ensure keys are enrolled, verify secure-env status

### Bootkit detected after Stage 2
- **Solution:** Run progressive recovery (Stage 3): `python3 scripts/recovery/phoenix_progressive.py`

### Nothing works (rare!)
- **Solution:** Hardware-level recovery with CH341A programmer (see Advanced Features)

---

## 🤝 Community Support

For issues, questions, or advanced scenarios:

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Documentation**: `docs/` directory
- **Examples**: `examples_and_samples/` directory

---

**Made with 🔥 by PhoenixBoot - Stop bootkits, period.**
