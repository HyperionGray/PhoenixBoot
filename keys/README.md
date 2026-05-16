# 🔐 PhoenixBoot SecureBoot Keys Directory

This directory contains your **SecureBoot key hierarchy** - the cryptographic foundation that controls what can boot on your system.

## 📚 Understanding SecureBoot Keys

SecureBoot uses a hierarchical trust model with three key types:

### 1️⃣ **PK (Platform Key)** - The Root of Trust
- **Files**: `PK.key`, `PK.crt`, `PK.cer`
- **Purpose**: The ultimate authority - owns the entire SecureBoot system
- **Uses**: Signs KEK updates, can reset SecureBoot to Setup Mode
- **Analogy**: Like the root password for your BIOS SecureBoot settings

### 2️⃣ **KEK (Key Exchange Key)** - Intermediate Authority  
- **Files**: `KEK.key`, `KEK.crt`, `KEK.cer`
- **Purpose**: Intermediary that can update the signature database (db)
- **Uses**: Signs db updates, allows adding new bootloaders
- **Analogy**: Like an admin account that can modify which programs can boot

### 3️⃣ **db (Signature Database)** - Authorized Bootloaders
- **Files**: `db.key`, `db.crt`, `db.cer`
- **Purpose**: Actually signs bootloaders and kernels
- **Uses**: Sign BOOTX64.EFI, shimx64.efi, grubx64.efi, kernels
- **Analogy**: Like the actual signing certificate for your boot files

## 🎯 Key Usage Guide

### When You Need Each Key:

| Task | Key Used | Command Example |
|------|----------|----------------|
| Sign a bootloader (BOOTX64.EFI) | **db** | `sbsign --key db.key --cert db.crt` |
| Sign a shim or GRUB | **db** | `sbsign --key db.key --cert db.crt` |
| Update signature database | **KEK** | Used in `.auth` file creation |
| Reset SecureBoot | **PK** | Used in `.auth` file creation |
| Enroll keys on system | **All** | `./pf.py secure-make-auth` then boot KeyEnrollEdk2.efi |

## 🔄 Common Workflows

### 🆕 First Time Setup
```bash
# 1. Generate keys (run once)
./pf.py secure-keygen

# 2. Create enrollment files
./pf.py secure-make-auth

# 3. Create bootable media with your ISO
ISO_PATH=/path/to/ubuntu.iso ./pf.py secureboot-create

# 4. Boot from media and enroll keys
#    Select "Enroll PhoenixGuard SecureBoot Keys" from GRUB menu
```

### 🔧 Signing a Custom Bootloader
```bash
# The ESP packaging automatically uses db keys to sign BOOTX64.EFI
./pf.py build-package-esp

# To manually sign something:
sbsign --key keys/db.key --cert keys/db.crt \
  --output signed.efi original.efi
```

### 📦 Creating a SecureBoot Bootable USB
```bash
# This uses db keys automatically to sign all EFI files
ISO_PATH=/path/to/your.iso ./pf.py secureboot-create

# Or use the standalone script:
./create-secureboot-bootable-media.sh --iso /path/to/your.iso
```

## 🚨 Security Best Practices

### ✅ DO:
- **Keep `.key` files SECRET** - they're your private keys!
- Back up this entire directory to secure storage
- Use strong permissions: `chmod 600 *.key`
- Keep keys offline when not in use
- Document what you sign with these keys

### ❌ DON'T:
- Share `.key` files with anyone
- Commit them to public repositories (the project `.gitignore` blocks
  `*.key` / `*.pem` / `*.der`, but if you re-create this directory
  manually take care not to override the rule)
- Store them on shared/networked drives
- Re-use keys across different systems (generate unique keys per machine)

> **Note for first-time users.** This directory is intentionally empty
> in the upstream repo for the `v0.1.0-alpha` release; previous tags
> shipped real-looking private keys, which was a mistake. Generate your
> own with `./pf.py secure-keygen` before doing anything else.

## 📂 File Format Reference

| Extension | Format | Contains | Use Case |
|-----------|--------|----------|----------|
| `.key` | PEM | Private key | Signing operations (KEEP SECRET!) |
| `.crt` | PEM | X.509 certificate | Public verification, enrollment |
| `.cer` | DER | X.509 certificate | Binary format for UEFI variables |

## 🔗 Related Directories

- `out/securevars/` - Contains `.auth` and `.esl` enrollment files
- `out/keys/mok/` - MOK (Machine Owner Key) for kernel module signing
- `staging/boot/` - Pre-built EFI binaries (BOOTX64.EFI, KeyEnrollEdk2.efi)

## 📖 Further Reading

- **UEFI Specification**: https://uefi.org/specifications
- **SecureBoot Explained**: See `docs/SECURE_BOOT.md` in this repository
- **Bootable Media Guide**: See `SECUREBOOT_QUICKSTART.md` in this repository

## ❓ Troubleshooting

### "Which shim do I need to enroll?"
If you're loading an OS from an ISO with SecureBoot:
- **Option 1** (Easiest): Use Microsoft-signed shim - works immediately, no enrollment needed
- **Option 2** (More secure): Sign your own shim with `db.key` + `db.crt`, then enroll these PhoenixGuard keys

When PhoenixBoot creates bootable media, it includes BOTH options!

### "I have multiple directories with keys - which one?"
PhoenixBoot organizes keys by purpose:
- `keys/` (this dir) - **SecureBoot keys** (PK, KEK, db) for bootloaders
- `out/keys/mok/` - **MOK keys** for signing kernel modules
- Each serves a different purpose - see sections above!

### "My bootloader won't boot - signature verification failed"
1. Check if it's signed: `sbverify --cert keys/db.crt file.efi`
2. Re-sign if needed: `sbsign --key keys/db.key --cert keys/db.crt ...`
3. Ensure your db keys are enrolled in UEFI (check with `mokutil --sb-state`)

---

**Need help?** See the main README.md or open an issue on GitHub.
