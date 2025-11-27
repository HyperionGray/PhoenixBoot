# 🎓 Understanding Boot Artifacts and Keys in PhoenixBoot

This guide helps users understand the various boot artifacts, keys, and shims in PhoenixBoot - what they are, why they exist, and when to use each one.

## 🤔 The Problem This Solves

When working with SecureBoot and bootable media, you often encounter:
- Multiple directories with similar files (shims, bootloaders)
- Confusion about which keys to enroll
- Uncertainty about which artifacts to use for different scenarios
- Terms like "shim", "BOOTX64", "MOK" that aren't explained

**This document makes it all clear!**

## 📚 Boot Concepts 101

### What is UEFI Boot?

Modern computers use **UEFI** (Unified Extensible Firmware Interface) instead of old BIOS. When your computer boots:

1. **UEFI firmware** starts (built into your motherboard)
2. It looks for **EFI System Partition (ESP)** on your drives
3. It runs an **EFI bootloader** (usually `/EFI/BOOT/BOOTX64.EFI`)
4. The bootloader loads your operating system

### What is SecureBoot?

**SecureBoot** is a UEFI security feature that only allows **signed** bootloaders to run. It prevents malware from taking over your boot process.

To use SecureBoot, you need:
- **Keys enrolled** in UEFI firmware (tells UEFI what to trust)
- **Signed bootloaders** (proves they haven't been tampered with)

## 🔑 Key Types Explained

PhoenixBoot uses several types of keys. Here's what each does:

### 1️⃣ SecureBoot Keys (PK, KEK, db)

Located in: `keys/` directory

| Key | Full Name | Purpose | Example Use |
|-----|-----------|---------|-------------|
| **PK** | Platform Key | Root of trust - owns your system | Reset SecureBoot, sign KEK updates |
| **KEK** | Key Exchange Key | Can update signature database | Sign db updates |
| **db** | Signature Database | Authorizes bootloaders | Sign BOOTX64.EFI, shimx64.efi, grubx64.efi |

**Key Hierarchy:**
```
PK (Platform Key)
 └── Signs KEK
     └── Signs db
         └── Signs bootloaders (BOOTX64.EFI, etc.)
```

**When you create keys:**
```bash
./pf.py secure-keygen  # Creates PK, KEK, db in keys/
```

**See also:** `keys/README.md` for detailed explanation

### 2️⃣ MOK Keys (Machine Owner Keys)

Located in: `out/keys/mok/` directory

**Purpose:** Sign kernel modules (.ko files) so they load with SecureBoot enabled

**Example:** You need to sign the APFS driver to read Mac drives:
```bash
./pf.py secure-mok-new                          # Generate MOK
./pf.py os-mok-enroll                           # Enroll on your system
./sign-kernel-modules.sh /path/to/apfs.ko      # Sign the module
```

**See also:** `out/keys/mok/README.md` for detailed explanation

## 🎯 Boot Artifacts Explained

### What is a "Shim"?

**shimx64.efi** is a small bootloader that acts as a bridge for SecureBoot:

- **Microsoft-signed shim**: Pre-signed by Microsoft, works immediately on most PCs
- **Custom shim**: You sign it yourself with your `db` key

**Why use a shim?**
- It's already signed by Microsoft (most PCs trust Microsoft keys out of the box)
- It can load GRUB even if GRUB isn't signed by Microsoft
- It includes MOK Manager for enrolling your own keys

**Where PhoenixBoot gets shims:**
- From your system: `/usr/lib/shim/shimx64.efi` (if installed)
- From your ESP: `/boot/efi/EFI/ubuntu/shimx64.efi`

### What is BOOTX64.EFI?

**BOOTX64.EFI** is the default boot filename that UEFI firmware looks for.

In PhoenixBoot, this can be:
- **PhoenixGuard's NuclearBoot** (our custom bootloader) - signed with your db key
- **Microsoft-signed shim** (chainloads to GRUB) - already signed
- **Any other bootloader** you choose

**Naming convention:**
- `BOOTX64.EFI` (uppercase) = Default boot file in `/EFI/BOOT/`
- `BootX64.efi` (mixed case) = Copy in `/EFI/PhoenixGuard/` (our vendor directory)

### What is grubx64.efi?

**grubx64.efi** is the GRUB bootloader (what shows the boot menu). It:
- Chainloaded by shim (shim → GRUB → kernel)
- Can be signed by your db key or trusted via MOK
- Reads `grub.cfg` to know what to boot

## 📦 Artifact Locations in PhoenixBoot

After building, you'll find artifacts in multiple places:

### Development/Staging
```
staging/boot/
  ├── NuclearBootEdk2.efi    ← Our custom secure bootloader
  ├── KeyEnrollEdk2.efi       ← Key enrollment tool
  └── UUEFI.efi               ← UEFI diagnostic tool
```

### Build Output
```
out/staging/
  ├── BootX64.efi             ← Copy of NuclearBootEdk2 (signed)
  ├── KeyEnrollEdk2.efi       ← Key enrollment tool
  └── UUEFI.efi               ← Diagnostic tool

out/esp/
  ├── esp.img                 ← Bootable ESP image
  └── mount/                  ← Mounted ESP contents
      └── EFI/
          ├── BOOT/
          │   ├── BOOTX64.EFI      ← Default boot (signed with db)
          │   ├── KeyEnrollEdk2.efi ← For enrolling keys
          │   └── grub.cfg         ← GRUB configuration
          └── PhoenixGuard/
              ├── BootX64.efi       ← Vendor copy (signed)
              ├── shimx64.efi       ← Microsoft-signed shim (if found)
              ├── grubx64.efi       ← GRUB bootloader
              └── keys/             ← Your enrollment files (.auth)
```

### Key Storage
```
keys/                         ← SecureBoot keys (PK, KEK, db)
  ├── PK.key, PK.crt, PK.cer
  ├── KEK.key, KEK.crt, KEK.cer
  ├── db.key, db.crt, db.cer
  └── README.md               ← Explains these keys

out/keys/mok/                 ← MOK keys (for kernel modules)
  ├── PGMOK.key, PGMOK.crt
  ├── PGMOK.der, PGMOK.pem
  └── README.md               ← Explains MOK keys

out/securevars/               ← Enrollment files
  ├── PK.auth, PK.esl
  ├── KEK.auth, KEK.esl
  └── db.auth, db.esl
```

## 🎬 Common Scenarios Explained

### Scenario 1: I want to create a bootable USB with SecureBoot

**Problem:** Which shim do I use? Which keys do I enroll?

**Solution:**
```bash
ISO_PATH=/path/to/ubuntu.iso ./pf.py secureboot-create
```

**What PhoenixBoot does:**
1. Generates keys (PK, KEK, db) if you don't have them
2. Finds Microsoft-signed shim on your system
3. Creates ESP with **both** options:
   - **BOOTX64.EFI** = Microsoft shim (works immediately)
   - **KeyEnrollEdk2.efi** = Tool to enroll your own keys (for more security)
4. Includes your ISO in `/ISO/` directory
5. Creates GRUB menu with options

**First boot:**
- **Easy mode:** Boot with SecureBoot ON, Microsoft shim works immediately
- **Secure mode:** Boot with SecureBoot OFF, enroll your keys first, then enable SecureBoot

**The shim to use:** The one in `/EFI/PhoenixGuard/shimx64.efi` (Microsoft-signed)

### Scenario 2: I want to sign kernel modules for SecureBoot

**Problem:** I need to load APFS driver but SecureBoot blocks it

**Solution:**
```bash
# 1. Generate MOK key (one-time)
./pf.py secure-mok-new

# 2. Enroll MOK on your system
./pf.py os-mok-enroll
# Enter a password when prompted

# 3. Reboot - MOK Manager appears
sudo reboot
# Choose "Enroll MOK" and enter the password

# 4. Sign the module
./sign-kernel-modules.sh /path/to/apfs.ko

# 5. Load it
sudo modprobe apfs
```

**The key to use:** MOK key in `out/keys/mok/PGMOK.crt`

**NOT the SecureBoot keys!** MOK is specifically for modules, not bootloaders.

### Scenario 3: Multiple Key Directories - Which One?

**Problem:** I see keys in `keys/`, `out/keys/`, `out/keys/mok/` - confused!

**Answer:**

| Directory | Contains | Purpose |
|-----------|----------|---------|
| `keys/` | SecureBoot keys (PK, KEK, db) | Sign bootloaders, enroll in UEFI |
| `out/keys/mok/` | MOK keys (PGMOK) | Sign kernel modules |
| `out/securevars/` | Enrollment files (.auth) | Used by KeyEnrollEdk2.efi |

**They're all different and serve different purposes!**

### Scenario 4: Which BOOTX64 File to Use?

**Problem:** I see BOOTX64.EFI in multiple places

**Answer:**

| Location | What it is | When to use |
|----------|-----------|-------------|
| `staging/boot/NuclearBootEdk2.efi` | Source binary (unsigned) | Development only |
| `out/staging/BootX64.efi` | Same as above (unsigned) | Build artifact |
| `out/esp/mount/EFI/BOOT/BOOTX64.EFI` | **Signed** bootloader | ✅ Use this for actual booting |
| `out/esp/mount/EFI/PhoenixGuard/BootX64.efi` | Vendor copy (signed) | Backup/reference |

**The one to use:** The signed one in the ESP image (`out/esp/mount/EFI/BOOT/BOOTX64.EFI`)

## 🚀 Decision Flow Chart

```
Do you need to...

┌─ Boot an OS with SecureBoot?
│   ├─ Easy way: Use Microsoft-signed shim
│   │   └─ Run: ./pf.py secureboot-create
│   └─ Secure way: Enroll your own keys
│       └─ Run: ./pf.py secure-keygen, then secureboot-create
│
┌─ Sign kernel modules?
│   └─ Use MOK keys
│       └─ Run: ./pf.py secure-mok-new, then sign-kernel-modules.sh
│
┌─ Sign a custom bootloader?
│   └─ Use db key from keys/ directory
│       └─ sbsign --key keys/db.key --cert keys/db.crt
│
└─ Understand what keys you have?
    ├─ SecureBoot keys: ls keys/
    ├─ MOK keys: ./pf.py os-mok-list-keys
    └─ Read: keys/README.md and out/keys/mok/README.md
```

## 🔍 Verification Commands

### Check what keys you have:
```bash
# SecureBoot keys
ls -lh keys/

# MOK keys
ls -lh out/keys/mok/

# Check enrollment status
./pf.py os-mok-list-keys
```

### Verify a signed file:
```bash
# Verify bootloader signature
sbverify --cert keys/db.crt /path/to/BOOTX64.EFI

# Verify module signature
modinfo /path/to/module.ko | grep sig
```

### Check SecureBoot status:
```bash
# System SecureBoot state
mokutil --sb-state

# Enrolled keys
mokutil --list-enrolled
```

## 📖 Quick Reference

| Task | Command | Keys Used | Output |
|------|---------|-----------|--------|
| Generate SecureBoot keys | `./pf.py secure-keygen` | Creates PK, KEK, db | `keys/` |
| Generate MOK keys | `./pf.py secure-mok-new` | Creates PGMOK | `out/keys/mok/` |
| Create enrollment files | `./pf.py secure-make-auth` | Uses PK, KEK, db | `out/securevars/` |
| Sign bootloader | `sbsign --key keys/db.key ...` | db | Signed .efi |
| Sign kernel module | `./sign-kernel-modules.sh` | PGMOK | Signed .ko |
| Create bootable media | `./pf.py secureboot-create` | All SecureBoot keys | `out/esp/` |
| Enroll MOK | `./pf.py os-mok-enroll` | PGMOK.der | System enrolled |

## 🎓 Learning Resources

### Recommended Reading Order:
1. This document (you're here!)
2. `keys/README.md` - SecureBoot key details
3. `out/keys/mok/README.md` - MOK key details
4. `SECUREBOOT_QUICKSTART.md` - Quick start guide
5. `docs/SECURE_BOOT.md` - Deep dive technical docs

### External Resources:
- [UEFI Specification](https://uefi.org/specifications)
- [Linux Kernel Module Signing](https://www.kernel.org/doc/html/latest/admin-guide/module-signing.html)
- [shim Documentation](https://github.com/rhboot/shim)

## ❓ FAQ

**Q: Why are there so many key types?**  
A: Each serves a different security layer - SecureBoot keys protect the boot chain, MOK keys protect kernel modules. They're separate by design.

**Q: Can I use the same keys for everything?**  
A: No! SecureBoot keys and MOK keys are different types and serve different purposes. Use the right key for each task.

**Q: Which shim should I use when loading an ISO?**  
A: Use the Microsoft-signed shim (PhoenixBoot finds it automatically). It works immediately without custom key enrollment.

**Q: I have keys in multiple directories - which one?**  
A: See "Scenario 3" above. Short answer: `keys/` for bootloaders, `out/keys/mok/` for modules.

**Q: Do I need to enroll all keys?**  
A: For full SecureBoot: Yes, enroll PK/KEK/db. For module signing: Yes, enroll MOK. But if using Microsoft shim, you can skip custom SecureBoot keys.

## 💡 Pro Tips

1. **Start simple**: Use Microsoft-signed shim first, add custom keys later
2. **Read the output**: PhoenixBoot scripts now tell you what they created and how to use it
3. **Check README files**: Every key directory has a README explaining its purpose
4. **Use the tools**: `./pf.py os-mok-list-keys` shows enrollment status
5. **Keep a log**: When you enroll keys, document what you did (the system will boot differently!)

---

**Still confused?** Open an issue on GitHub with your specific question!

**Want to contribute?** Help us make these explanations even clearer!
