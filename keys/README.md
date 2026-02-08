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

# 3. Create (or write) an OS installer USB
./pf.py secureboot-create iso_path=/path/to/ubuntu.iso
./pf.py secureboot-create iso_path=/path/to/ubuntu.iso usb_device=/dev/sdX  # DESTRUCTIVE (secureboot-create-usb alias)

# 4. Enroll keys (advanced / optional)
#    See: docs/SECUREBOOT_ENABLEMENT_KEXEC.md (or enroll via firmware UI using out/securevars/*.auth)
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
# Create a ready-to-write installer image in out/esp/
./pf.py secureboot-create iso_path=/path/to/your.iso

# Or write directly (DESTRUCTIVE)
./pf.py secureboot-create iso_path=/path/to/your.iso usb_device=/dev/sdX  # (same as secureboot-create-usb)

# Or use the standalone script directly:
./create-secureboot-bootable-media.sh --iso /path/to/your.iso --usb-device /dev/sdX
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
- Commit them to public repositories (they're in .gitignore)
- Store them on shared/networked drives
- Re-use keys across different systems (generate unique keys per machine)

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
- **Option 1** (Easiest): Use the distro installer as-is (most mainstream installers are already SecureBoot-signed)
- **Option 2** (More secure): Enroll your own PK/KEK/db and sign the boot chain with `keys/db.key` + `keys/db.crt`

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
