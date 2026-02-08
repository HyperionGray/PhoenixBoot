# Secure Boot Enablement via Double Kexec Method

> **⚠️ IMPORTANT: Host-only advanced workflow**
> 
> PhoenixBoot can orchestrate a **double-kexec** workflow and (optionally) enroll keys via
> standard UEFI variables (Setup Mode required). It does **NOT** attempt firmware patching.
> 
> Secure Boot enablement can still be hardware/firmware-specific and may require:
> - Manufacturer-specific tools
> - Firmware-specific knowledge
> - A BIOS/UEFI toggle (common)
> - **OR the traditional BIOS/UEFI setup method (often the safest)**
> 
> For Phase 2, you can supply a custom command with `--phase2-cmd '...'` (auto switches to `--action=run_cmd`).

## Overview

PhoenixBoot provides an advanced **framework** for enabling Secure Boot from the operating system using the "double kexec" technique. This demonstrates how to enable Secure Boot without requiring multiple reboots, even when the kernel has hardened security protections that normally prevent BIOS/firmware modifications.

### Framework vs. Complete Implementation

**What this provides:**
- ✅ Double-kexec workflow orchestration (Phase 1 → Phase 2 → Phase 3)
- ✅ Optional key enrollment via `efi-updatevar` when in Setup Mode
- ✅ Optional Phase 2 hook via `--phase2-cmd '...'` (runs after key enrollment/prep)
- ✅ Kernel configuration profiles (permissive, hardened, balanced)
- ✅ Status detection and analysis tools
- ✅ Prerequisites checking and validation
- ✅ Educational demonstration of the technique

**What this does NOT provide:**
- ❌ Vendor-specific firmware patching / flashrom automation
- ❌ A universal “flip Secure Boot on” switch (many platforms require BIOS/UEFI enable)
- ❌ Universal UEFI variable manipulation

**Recommended for most users:** Enable Secure Boot through BIOS/UEFI setup (traditional method).

## The Problem

Enabling Secure Boot typically requires:
1. Booting with a kernel that allows BIOS access (relaxed security)
2. Modifying UEFI variables or firmware to enable Secure Boot
3. Rebooting with a hardened kernel (maximum security)

This traditionally requires **multiple reboots**, which is time-consuming and disruptive.

## The Solution: Double Kexec Method

The double kexec method solves this problem by using `kexec` to switch between kernels without rebooting:

```
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Current Hardened Kernel                            │
│ - Maximum security enabled                                  │
│ - Cannot modify BIOS/firmware                               │
└────────────────┬────────────────────────────────────────────┘
                 │ kexec (no power cycle)
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 2: Alternate Kernel (Permissive)                     │
│ - Relaxed security for BIOS access                         │
│ - Enable Secure Boot via UEFI vars or flashrom            │
│ - CONFIG_DEVMEM=y, lockdown disabled                       │
└────────────────┬────────────────────────────────────────────┘
                 │ kexec (no power cycle)
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Phase 3: Hardened Kernel (Maximum Security)                │
│ - Secure Boot now enabled                                  │
│ - CONFIG_DEVMEM=n, lockdown enforced                       │
│ - Cannot repeat the trick (security locked)                │
└─────────────────────────────────────────────────────────────┘
```

**Key Benefit**: No power cycle reboots required between phases!

## Quick Start

### Check Current Secure Boot Status

```bash
# Check if Secure Boot is enabled and if you can enable it
./pf.py secureboot-check
```

This will show:
- UEFI system status
- Current Secure Boot state (enabled/disabled)
- Setup Mode status
- Kernel configuration for BIOS flashing
- Kexec availability
- Recommendations

### Enable Secure Boot via Double Kexec

```bash
# Optional: preview what will happen (no changes)
./pf.py secureboot-prepare-kexec

# Enable Secure Boot using the double kexec method
sudo ./pf.py secureboot-enable-kexec
```

**Warning**: This is an advanced operation. Read all prompts carefully.

## Prerequisites

### Required Tools

```bash
# Install required tools
sudo apt install kexec-tools efibootmgr flashrom

# Verify installation
which kexec efibootmgr flashrom
```

### Required Kernel Configuration

The system needs:
1. **At least two kernel versions** installed (one hardened, one permissive)
2. **Kexec support** enabled in at least one kernel (`CONFIG_KEXEC=y`)
3. **UEFI system** with Secure Boot capability

### Check Your System

```bash
# Check current kernel config
./pf.py kernel-hardening-check

# Check kexec availability
./pf.py kernel-kexec-check

# View kexec workflow guide
./pf.py kernel-kexec-guide
```

## Kernel Configuration Profiles

PhoenixBoot provides three kernel configuration profiles:

### 1. Permissive Profile (for BIOS modification)

Use temporarily during Phase 2 to enable Secure Boot:

```bash
# Generate permissive config
./pf.py kernel-profile-permissive
# Output: out/kernel-profiles/permissive.config

# View profile details
./pf.py kernel-profile-list
```

**Key settings:**
- `CONFIG_DEVMEM=y` - Allow direct hardware access
- `CONFIG_STRICT_DEVMEM=n` - Don't restrict /dev/mem
- `CONFIG_SECURITY_LOCKDOWN_LSM=n` - Disable lockdown
- `CONFIG_KEXEC=y` - Enable kexec for double-jump

**Security Level**: Low (temporary use only!)

### 2. Hardened Profile (maximum security)

Use after Secure Boot is enabled:

```bash
# Generate hardened config
./pf.py kernel-profile-hardened
# Output: out/kernel-profiles/hardened.config
```

**Key settings:**
- `CONFIG_DEVMEM=n` - Block direct hardware access
- `CONFIG_STRICT_DEVMEM=y` - Restrict memory access
- `CONFIG_SECURITY_LOCKDOWN_LSM=y` - Enable lockdown
- `CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY=y` - Force integrity mode
- `CONFIG_KEXEC=n` - Disable kexec (prevent kernel bypass)
- `CONFIG_MODULE_SIG_FORCE=y` - Require signed modules

**Security Level**: Maximum (production use)

### 3. Balanced Profile (flexibility + security)

Good for general use with Secure Boot:

```bash
# Generate balanced config
./pf.py kernel-profile-balanced
# Output: out/kernel-profiles/balanced.config
```

**Key settings:**
- `CONFIG_DEVMEM=y` with `CONFIG_STRICT_DEVMEM=y` (restricted access)
- `CONFIG_SECURITY_LOCKDOWN_LSM=y` in integrity mode
- `CONFIG_KEXEC=y` with `CONFIG_KEXEC_SIG=y` (signed kexec only)
- `CONFIG_MODULE_SIG_FORCE=y` - Require signed modules

**Security Level**: High (good balance)

### Compare Current Config with Profile

```bash
# Compare current kernel with permissive profile
PROFILE=permissive ./pf.py kernel-profile-compare

# Compare with hardened profile
PROFILE=hardened ./pf.py kernel-profile-compare

# Compare with balanced profile
PROFILE=balanced ./pf.py kernel-profile-compare
```

## Step-by-Step Workflow

### Step 1: Prepare Alternate Kernels

You need at least two kernel versions:

1. **Permissive kernel** (for Phase 2 - BIOS access)
2. **Hardened kernel** (for Phase 3 - production use)

#### Build Permissive Kernel

```bash
# Generate permissive config
./pf.py kernel-profile-permissive

# Copy to kernel source
cd /usr/src/linux-$(uname -r)
cp ~/PhoenixBoot/out/kernel-profiles/permissive.config .config

# Update config
make olddefconfig

# Build kernel
make -j$(nproc)

# Install
sudo make modules_install
sudo make install

# Update bootloader
sudo update-grub
```

#### Build Hardened Kernel

```bash
# Generate hardened config
./pf.py kernel-profile-hardened

# Copy to kernel source
cd /usr/src/linux-$(uname -r)
cp ~/PhoenixBoot/out/kernel-profiles/hardened.config .config

# Update config
make olddefconfig

# Build kernel
make -j$(nproc)

# Install
sudo make modules_install
sudo make install

# Update bootloader
sudo update-grub
```

### Step 2: Check Secure Boot Status

```bash
# Comprehensive check
./pf.py secureboot-check
```

Review the output to ensure:
- ✓ UEFI system
- ✓ Secure Boot currently disabled (or you wouldn't need this)
- ✓ Kexec available
- ✓ At least two kernels installed

### Step 3: Enable Secure Boot via Double Kexec

```bash
# Run the enablement script
sudo ./pf.py secureboot-enable-kexec
```

The script will:
1. Check prerequisites
2. Show available kernels
3. Load alternate kernel via kexec
4. Execute kexec (switch to permissive kernel)
5. In Phase 2, optionally enroll keys via `efi-updatevar` (Setup Mode required) and/or run a custom command
6. Kexec back to hardened kernel

**Note**: Many platforms still require enabling Secure Boot in BIOS/UEFI settings even after keys are enrolled.

### Step 4: Verify Secure Boot is Enabled

After the process completes:

```bash
# Check Secure Boot status
./pf.py secureboot-check

# Should show: ✓ Secure Boot is ENABLED
```

## Alternative: Traditional Method

If the double kexec method is not suitable for your system, use the traditional method:

### Option 1: Enable via BIOS/UEFI Setup

1. Reboot your system
2. Enter BIOS/UEFI setup (usually Del, F2, or F12)
3. Navigate to Security → Secure Boot
4. Enable Secure Boot
5. Save and exit

This is the **safest and recommended method** for most users.

### Option 2: Direct OS Enablement

If your platform is in **Setup Mode** (keys cleared) and you want to enroll PhoenixBoot keys from the OS without kexec:

```bash
# This command attempts direct enablement
# Requires Setup Mode + efitools (efi-updatevar)
sudo ./pf.py secureboot-enable-direct
```

## Security Considerations

### Why Disable Kexec After Enabling Secure Boot?

The final hardened kernel **disables kexec** (`CONFIG_KEXEC=n`) to prevent:
- Attackers using the same double kexec trick
- Bypassing Secure Boot with unsigned kernels
- Runtime kernel replacement attacks

Once Secure Boot is enabled and the hardened kernel is running, the system is **locked down** and cannot be modified without:
1. Rebooting into BIOS/UEFI setup
2. Disabling Secure Boot
3. Booting with a permissive kernel

This is **by design** - it maintains security after setup.

### Kernel Lockdown Modes

The kernel lockdown feature has three modes:

1. **None** (`lockdown=none`)
   - No restrictions
   - Full hardware access
   - **Use only for permissive kernel (Phase 2)**

2. **Integrity** (`lockdown=integrity`)
   - Prevents unsigned kernel modifications
   - Allows signed kexec
   - **Good for balanced kernel**

3. **Confidentiality** (`lockdown=confidentiality`)
   - Maximum restrictions
   - Blocks kexec entirely (even signed)
   - **Use for hardened kernel (Phase 3)**

## Troubleshooting

### Kexec Not Available

```bash
# Check if kexec is installed
which kexec
# If not: sudo apt install kexec-tools

# Check kernel support
./pf.py kernel-kexec-check
```

If kexec is not supported, you'll need to rebuild your kernel with `CONFIG_KEXEC=y`.

### Kernel Lockdown Blocks Kexec

If you see:
```
✗ Kernel lockdown: CONFIDENTIALITY - BIOS flashing blocked
```

Solutions:
1. Boot with `lockdown=none` or `lockdown=integrity` kernel parameter
2. Use a kernel that doesn't force lockdown
3. Use traditional reboot method

### Secure Boot Already Enabled

```bash
# Check status
./pf.py secureboot-check

# If already enabled, you're done!
```

### No Alternate Kernels Available

Install additional kernel:

```bash
# Ubuntu/Debian
sudo apt install linux-image-generic

# Fedora
sudo dnf install kernel

# Check available kernels
ls /boot/vmlinuz-*
```

### Cannot Access /dev/mem

If you see:
```
✗ /dev/mem exists but is not accessible
```

Causes:
- `CONFIG_DEVMEM=n` - Kernel compiled without /dev/mem
- `CONFIG_STRICT_DEVMEM=y` - Access restricted to system RAM
- Kernel lockdown enabled

Solution: Use the permissive kernel profile.

## Advanced Usage

### Generate Custom Kernel Config

```bash
# Start with a profile
./pf.py kernel-profile-balanced

# Edit the config
vim out/kernel-profiles/balanced.config

# Apply to kernel source
cd /usr/src/linux
cp ~/PhoenixBoot/out/kernel-profiles/balanced.config .config
make menuconfig  # Customize further
make olddefconfig
```

### Check Kernel Hardening Level

```bash
# Detailed analysis
./pf.py kernel-hardening-check

# Generate reports
./pf.py kernel-hardening-report
# Output: out/reports/kernel_hardening_report.txt
#         out/reports/kernel_hardening_report.json
```

### Compare Configs Before and After

```bash
# Before (current)
PROFILE=permissive ./pf.py kernel-profile-compare > before.txt

# After building permissive kernel, boot into it
# Then check
PROFILE=permissive ./pf.py kernel-profile-compare > after.txt

# Compare
diff before.txt after.txt
```

## Integration with PhoenixBoot

The Secure Boot enablement feature integrates with PhoenixBoot's existing capabilities:

### Generate Secure Boot Keys

```bash
# Generate custom keys
./pf.py secure-keygen

# Create auth files
./pf.py secure-make-auth
```

### Enroll Custom Keys

After enabling Secure Boot, enroll your custom keys:

```bash
# Install KeyEnrollEdk2.efi
# Boot from ESP
# Select "Enroll Keys" option
```

### Sign Kernel Modules

With Secure Boot enabled, modules must be signed:

```bash
# Generate MOK key
./pf.py secure-mok-new

# Enroll MOK
./pf.py os-mok-enroll

# Sign a module
MODULE_PATH=/lib/modules/$(uname -r)/kernel/drivers/net/wireless/intel/iwlwifi/iwlwifi.ko ./pf.py os-kmod-sign

# Sign all modules
MODULE_PATH=/lib/modules/$(uname -r) FORCE=1 ./pf.py os-kmod-sign
```

## Limitations and Considerations

### Hardware Compatibility

Not all systems support OS-level Secure Boot enablement:
- Some UEFI implementations lock Secure Boot settings
- Manufacturer-specific firmware may require special tools
- Some systems require BIOS/UEFI setup for enablement

### Security vs. Convenience Trade-off

The double kexec method provides convenience but involves:
1. Temporarily running a less secure kernel (Phase 2)
2. Complexity that could introduce errors
3. System interruption during kexec

**Recommendation**: For production systems, use the traditional BIOS/UEFI setup method.

### Testing in Virtual Machines

Test the workflow in a VM first:

```bash
# QEMU with OVMF (UEFI firmware)
./pf.py test-qemu-secure-positive

# This simulates Secure Boot environment
```

### Backup and Recovery

Before attempting:
1. **Backup important data**
2. Have a recovery USB ready
3. Know how to enter BIOS/UEFI setup
4. Test in a VM first if possible

## FAQ

**Q: Why not just enable Secure Boot in BIOS?**

A: That's the recommended method! The double kexec method is for:
- Remote systems where rebooting is expensive
- Automated provisioning workflows
- Learning about kernel security features

**Q: Is this safe?**

A: Yes, when done correctly. The temporary permissive kernel (Phase 2) only runs briefly. The final hardened kernel locks down the system.

**Q: Can I use this in production?**

A: The framework is provided for educational and advanced use cases. For production, enabling Secure Boot through BIOS/UEFI setup is recommended for safety and simplicity.

**Q: What if kexec fails?**

A: If kexec fails, the system remains in its current state. Simply reboot normally. The worst case is needing to use the traditional method.

**Q: Do I need to sign the alternate kernels?**

A: If your current kernel has lockdown in integrity or confidentiality mode, yes. The permissive kernel used in Phase 2 may need to be signed.

**Q: Can this brick my system?**

A: The kexec operations themselves are safe. Firmware modification (enabling Secure Boot) has inherent risks, but modern UEFI systems have protection mechanisms. Always have a backup and recovery plan.

## References

- [Linux Kernel Lockdown Documentation](https://www.kernel.org/doc/html/latest/security/lockdown.html)
- [Kexec Documentation](https://www.kernel.org/doc/Documentation/kexec.txt)
- [UEFI Secure Boot Specification](https://uefi.org/specs)
- [DISA STIG for RHEL](https://www.stigviewer.com/stig/red_hat_enterprise_linux_8/)

## See Also

- [Kernel Hardening Guide](KERNEL_HARDENING_GUIDE.md)
- [Secure Boot Implementation](SECURE_BOOT.md)
- [UUEFI Enhanced Features](UUEFI_ENHANCED.md)
- [Architecture Overview](../ARCHITECTURE.md)

---

**Made with 🔥 by PhoenixBoot**
