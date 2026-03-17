# 🔑 MOK (Machine Owner Key) Management

Complete guide for managing Machine Owner Keys for kernel module signing with SecureBoot enabled.

## 📚 What is MOK?

**MOK (Machine Owner Key)** is a mechanism that allows users to sign their own kernel modules so they can be loaded when SecureBoot is enabled. Without a properly enrolled MOK, custom kernel modules (like DKMS modules, third-party drivers, etc.) will be rejected by the kernel.

## 🚀 Quick Start - Complete Workflow

### Step 1: Generate MOK Key

```bash
# Generate a new MOK keypair
./pf.py secure-mok-new

# Or with custom name/CN
NAME=MyMOK CN="My Custom MOK" ./pf.py secure-mok-new
```

**Output**: Creates keys in `out/keys/mok/`:
- `PGMOK.key` - Private key (keep secret!)
- `PGMOK.crt` - Certificate (public)
- `PGMOK.der` - DER format certificate
- `PGMOK.pem` - Combined key+cert

### Step 2: Run preflight checks

```bash
# Validate enrollment readiness (files, permissions, Secure Boot state, pending/enrolled status)
./pf.py os-mok-preflight

# Strict mode: fail when any warning is present
MOK_STRICT=1 ./pf.py os-mok-preflight
```

### Step 3: Enroll MOK on Your System

```bash
# Enroll the MOK certificate
./pf.py os-mok-enroll

# You'll be prompted to set a password - remember it!
```

### Step 4: Reboot and Complete Enrollment

After running the enroll command:
1. **Reboot your system**
2. **MOK Manager will appear** during boot (blue screen)
3. **Select "Enroll MOK"**
4. **Enter the password** you set in Step 2
5. **Confirm** and continue boot

### Step 5: Verify Enrollment

```bash
# Check MOK status
./pf.py os-mok-list-keys

# Or manually
mokutil --list-enrolled
```

### Step 6: Sign Kernel Modules

```bash
# Sign a single module
./sign-kernel-modules.sh /path/to/module.ko

# Sign using pf task
PATH=/lib/modules/$(uname -r)/kernel/drivers/net/wireless/intel/iwlwifi/iwlwifi.ko ./pf.py os-kmod-sign

# Force re-sign already signed module
PATH=/path/to/module.ko FORCE=1 ./pf.py os-kmod-sign
```

## 📖 Detailed Scripts Reference

### Key Generation

#### `mok-new.sh`
Generate a new MOK keypair with certificate.

```bash
# Default name (PGMOK)
./scripts/mok-management/mok-new.sh

# Custom name and CN
./scripts/mok-management/mok-new.sh MyMOK "My Module Key"
```

**Creates**:
- RSA-4096 private key
- Self-signed X.509 certificate (10 years validity)
- DER format certificate
- Combined PEM file

### Enrollment Operations

#### `enroll-mok.sh`
Enroll MOK certificate into the system.

```bash
./scripts/mok-management/enroll-mok.sh <cert.crt> <cert.der>

# Via pf task
./pf.py os-mok-enroll
```

**What it does**:
1. Imports certificate to MOK database
2. Prompts for password (needed at next boot)
3. Schedules enrollment for next boot

**Requires**: `mokutil` package installed

#### `unenroll-mok.sh`
Remove an enrolled MOK certificate.

```bash
./scripts/mok-management/unenroll-mok.sh <cert.der>
```

### Status and Verification

#### `mok-status.sh`
Show SecureBoot state and enrolled MOKs.

```bash
./scripts/mok-management/mok-status.sh

# Via pf task
./pf.py secure-mok-status
```

#### `mok-list-keys.sh`
List available MOK certificates in the repository.

```bash
./scripts/mok-management/mok-list-keys.sh

# Via pf task
./pf.py os-mok-list-keys
```

**Shows**:
- All MOK certificates in `out/keys/mok/`
- Certificate details (subject, fingerprint, validity)
- Enrollment status

#### `mok-preflight.sh`
Run MOK readiness checks before enrollment or module signing.

```bash
./scripts/mok-management/mok-preflight.sh
./scripts/mok-management/mok-preflight.sh --strict
./scripts/mok-management/mok-preflight.sh --json

# Via pf task
./pf.py os-mok-preflight
MOK_STRICT=1 ./pf.py os-mok-preflight
```

**Checks**:
- UEFI availability, `openssl`, and `mokutil`
- Certificate/key/DER presence and key permissions
- Secure Boot state
- Enrolled and pending enrollment status for the selected cert
- Metadata presence in `out/keys/mok/*.meta.json`

#### `mok-verify.sh`
Verify MOK certificate details and integrity.

```bash
./scripts/mok-management/mok-verify.sh <cert.crt> <cert.der>

# Via pf task
MOK_CERT_PEM=out/keys/mok/PGMOK.crt MOK_CERT_DER=out/keys/mok/PGMOK.der ./pf.py secure-mok-verify
```

#### `mok-find-enrolled.sh`
Match local certificates to enrolled MOKs.

```bash
./scripts/mok-management/mok-find-enrolled.sh

# Via pf task
./pf.py secure-mok-find-enrolled
```

### Module Signing

#### `sign-kmods.sh`
Sign kernel modules with MOK certificate.

```bash
# Sign single module
./scripts/mok-management/sign-kmods.sh /path/to/module.ko

# Sign all modules in directory
./scripts/mok-management/sign-kmods.sh /lib/modules/$(uname -r)/kernel/drivers/
```

**Top-level wrapper**: `sign-kernel-modules.sh` (repository root)

### Advanced Operations

#### `kmod-autoload.sh`
Setup automatic module loading on boot.

```bash
./scripts/mok-management/kmod-autoload.sh <module_name>
```

#### `kmod-setup-fastpath.sh`
Configure fast-path for frequently used modules.

```bash
./scripts/mok-management/kmod-setup-fastpath.sh
```

#### `fix-module-order.sh`
Fix module loading order dependencies.

```bash
./scripts/mok-management/fix-module-order.sh
```

## 🎯 Common Use Cases

### Use Case 1: DKMS Module (e.g., NVIDIA Driver)

```bash
# 1. Generate and enroll MOK
./pf.py secure-mok-new
./pf.py os-mok-enroll
# Reboot and complete enrollment in MOK Manager

# 2. Sign DKMS modules after installation
PATH=/lib/modules/$(uname -r)/updates/dkms ./pf.py os-kmod-sign

# 3. Load module
sudo modprobe nvidia
```

### Use Case 2: Third-Party Wireless Driver

```bash
# 1. Ensure MOK is enrolled (do once)
./pf.py os-mok-list-keys  # Check status

# 2. Sign the driver
./sign-kernel-modules.sh /lib/modules/$(uname -r)/kernel/drivers/net/wireless/rtl8xxxu/rtl8xxxu.ko

# 3. Load module
sudo modprobe rtl8xxxu
```

### Use Case 3: VirtualBox Kernel Modules

```bash
# After VirtualBox installation
PATH=/lib/modules/$(uname -r)/misc FORCE=1 ./pf.py os-kmod-sign
sudo modprobe vboxdrv
```

### Use Case 4: Automated Signing on Kernel Update

Create a script in `/etc/kernel/postinst.d/`:

```bash
#!/bin/bash
# /etc/kernel/postinst.d/zz-sign-modules

KERNEL_VERSION="$1"
MOK_KEY="/path/to/out/keys/mok/PGMOK.key"
MOK_CERT="/path/to/out/keys/mok/PGMOK.crt"

# Sign all modules in the new kernel
/path/to/PhoenixBoot/sign-kernel-modules.sh /lib/modules/$KERNEL_VERSION/
```

## 🔧 Troubleshooting

### MOK Enrollment Fails

**Symptom**: MOK Manager doesn't appear after reboot

**Solutions**:
1. Check if mokutil is installed: `which mokutil`
2. Verify SecureBoot is enabled: `mokutil --sb-state`
3. Check enrollment is pending: `mokutil --list-new`
4. Try enrolling again: `./pf.py os-mok-enroll`

### Module Won't Load After Signing

**Symptom**: `modprobe: ERROR: could not insert 'module': Required key not available`

**Solutions**:
1. Verify MOK is enrolled: `mokutil --list-enrolled | grep PhoenixGuard`
2. Check module signature: `modinfo module.ko | grep signer`
3. Re-sign with force: `PATH=/path/to/module.ko FORCE=1 ./pf.py os-kmod-sign`
4. Check dmesg for details: `dmesg | grep -i 'module verification'`

### Wrong Certificate Used for Signing

**Symptom**: Module signed but still rejected

**Solutions**:
1. Check which certificates are enrolled: `mokutil --list-enrolled`
2. Verify signing certificate matches enrolled: `./pf.py secure-mok-find-enrolled`
3. Set correct certificate path:
   ```bash
   KMOD_CERT=/path/to/correct.crt KMOD_KEY=/path/to/correct.key ./sign-kernel-modules.sh module.ko
   ```

### Permission Denied When Signing

**Symptom**: Cannot access signing key

**Solutions**:
1. Ensure key has correct permissions: `chmod 600 out/keys/mok/PGMOK.key`
2. Run signing as user who owns the keys (not root unless necessary)
3. Check key ownership: `ls -la out/keys/mok/`

## 🔐 Security Best Practices

1. **Protect Private Keys**
   - Keep `.key` files with 600 permissions
   - Never commit private keys to version control
   - Back up keys securely (encrypted storage)

2. **Certificate Validity**
   - MOK certificates are valid for 10 years by default
   - Plan for rotation before expiration
   - Track certificate fingerprints

3. **Signing Workflow**
   - Sign modules immediately after compilation
   - Verify signatures before deployment
   - Keep logs of signed modules

4. **Enrollment**
   - Use strong passwords for MOK enrollment
   - Document which certificates are enrolled where
   - Test in VM before deploying to production

## 🔗 Related Documentation

- [SecureBoot Quick Reference](../../SECUREBOOT_QUICKSTART.md)
- [Bootkit Defense Workflow](../../docs/BOOTKIT_DEFENSE_WORKFLOW.md)
- [Sign Kernel Modules Script](../../sign-kernel-modules.sh)
- [Core Tasks](../../core.pf) - See MOK-related tasks

## 📞 Support

For issues with MOK management:
1. Check this documentation
2. Review script output carefully
3. Check system logs: `journalctl -xe`
4. Open an issue on GitHub with details

---

**Made with 🔥 for secure kernel module loading**
