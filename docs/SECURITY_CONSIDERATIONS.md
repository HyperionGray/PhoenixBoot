# Security Considerations for SecureBoot Bootable Media

This document outlines security aspects of the turnkey SecureBoot bootable media creator.

## Overview

The `create-secureboot-bootable-media.sh` script handles sensitive cryptographic operations including key generation, signing, and boot chain creation. Understanding the security implications is important for users.

## Key Security Features

### 1. Cryptographic Key Generation

**What it does:**
- Generates RSA-4096 keys (PK, KEK, db)
- Uses OpenSSL with secure defaults
- 10-year validity period

**Security considerations:**
```bash
# Keys are generated with:
openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650
```

- ✅ RSA-4096 is considered secure for long-term use
- ✅ SHA-256 is cryptographically strong
- ⚠️ `-nodes` means no passphrase on private keys (for automation)
- ⚠️ Keys stored in plaintext in `keys/` directory

**Recommendations:**
- Back up keys to encrypted storage
- Set restrictive permissions: `chmod 600 keys/*.key`
- Consider encrypting the entire `keys/` directory
- For production use, consider using HSM or hardware security module

### 2. Key Storage

**What gets stored:**
```
keys/
├── PK.key  (private)  ← MOST SENSITIVE
├── PK.crt  (public)
├── KEK.key (private)  ← SENSITIVE
├── KEK.crt (public)
├── db.key  (private)  ← SENSITIVE
└── db.crt  (public)
```

**Security measures:**
- Script sets `chmod 600` on private keys
- Keys stay on local filesystem
- Not transmitted over network
- Not logged or echoed

**Risks:**
- ❌ Private keys could be read by root user
- ❌ Keys could be backed up unencrypted
- ❌ Keys could be exposed if system is compromised

**Mitigations:**
```bash
# Encrypt keys directory
tar czf - keys/ | gpg -c > keys-backup.tar.gz.gpg

# Store in encrypted partition
cryptsetup luksFormat /dev/sdX
cryptsetup open /dev/sdX encrypted_keys
mkfs.ext4 /dev/mapper/encrypted_keys
mount /dev/mapper/encrypted_keys /mnt/secure
cp -a keys/ /mnt/secure/
```

### 3. Code Signing

**What it does:**
- Signs bootloader with db key using sbsign
- Creates authenticated variables for PK, KEK, db

**Security considerations:**
```bash
sbsign --key keys/db.key --cert keys/db.crt --output signed.efi unsigned.efi
```

- ✅ Signing is done locally, offline
- ✅ Uses standard UEFI signing tools
- ✅ Signature includes full certificate chain
- ⚠️ Signature validity depends on key protection

**Verification:**
```bash
# Verify signature
sbverify --cert keys/db.crt signed.efi
```

### 4. Boot Chain Security

**Boot chain:**
```
Firmware → shim → GRUB → ISO kernel/initrd
```

**Security layers:**
1. **Firmware** - Verifies shim signature (Microsoft or custom PK/KEK/db)
2. **Shim** - Verifies GRUB signature (Microsoft or MOK)
3. **GRUB** - Boots ISO (no signature verification at this level)
4. **ISO** - Must handle its own signature verification

**Important notes:**
- ⚠️ ISO contents are NOT verified by SecureBoot
- ⚠️ GRUB loopback mounts ISO without verification
- ⚠️ Malicious ISO could compromise system after boot

**Recommendations:**
- Only use ISOs from trusted sources
- Verify ISO checksums independently
- Consider additional verification in ISO (IMA, dm-verity)

### 5. Microsoft-Signed Shim

**What it is:**
- Pre-signed bootloader from Microsoft
- Included from system packages (shim-signed)
- Already trusted by most UEFI firmware

**Security considerations:**
- ✅ Widely trusted and audited
- ✅ Works immediately without key enrollment
- ⚠️ Trusts Microsoft's signing authority
- ⚠️ May accept any Microsoft-signed payload

**Trade-offs:**
- **Convenience:** Works immediately on most systems
- **Trust:** You trust Microsoft's signing process
- **Alternative:** Use custom keys for full control

### 6. Custom Key Enrollment

**What it does:**
- Replaces/supplements firmware keys with custom keys
- Uses KeyEnrollEdk2.efi tool
- Requires physical access to system

**Security considerations:**
- ✅ Full control over trusted keys
- ✅ Can revoke Microsoft keys if desired
- ✅ Platform Key (PK) prevents unauthorized changes
- ⚠️ Incorrect enrollment can brick system
- ⚠️ Physical access required (prevents remote attacks)

**Risks:**
- ❌ Incorrect PK enrollment can lock you out
- ❌ Losing keys means reinstallation
- ❌ Some hardware has bugs in custom key handling

**Best practices:**
- Always back up original firmware keys first
- Test on virtual machine before real hardware
- Keep recovery media with original keys
- Document your key hierarchy

### 7. Authentication Variables

**What they are:**
```
PK.auth  - Platform Key (self-signed by PK)
KEK.auth - Key Exchange Key (signed by PK)
db.auth  - Signature Database (signed by KEK)
```

**Security considerations:**
- ✅ Signed with proper certificate chain
- ✅ UEFI firmware verifies signatures
- ✅ Prevents unauthorized key updates
- ⚠️ Must be installed in correct order (PK last!)

**Verification:**
```bash
# Check auth file signature
cert-to-efi-sig-list -s keys/PK.crt out/securevars/PK.esl
sign-efi-sig-list -k keys/PK.key -c keys/PK.crt PK out/securevars/PK.esl test.auth
diff out/securevars/PK.auth test.auth
```

## Threat Model

### What This Protects Against

✅ **Bootkit attacks** - Malicious bootloader replacement
✅ **Rootkit persistence** - Kernel-level malware
✅ **Evil maid attacks** - Physical tampering with boot media
✅ **Supply chain attacks** - Pre-installed malware in firmware

### What This Does NOT Protect Against

❌ **Compromised ISO** - If ISO itself is malicious
❌ **Firmware vulnerabilities** - UEFI firmware bugs
❌ **Physical attacks with key access** - If attacker has your keys
❌ **Runtime attacks** - After OS is booted
❌ **Side channels** - Timing, power analysis, etc.

## Security Best Practices

### For Key Management

1. **Generate keys offline** on secure system
2. **Encrypt backups** with strong passphrase
3. **Store securely** in encrypted storage
4. **Limit access** to keys (file permissions)
5. **Rotate periodically** (consider 1-2 year rotation)
6. **Document hierarchy** (who signs what)

### For Boot Media Creation

1. **Verify ISO checksums** before use
2. **Use official ISOs** from trusted sources
3. **Test in VM first** before production
4. **Keep logs** of what was created when
5. **Version control** your key sets
6. **Separate keys** for testing vs production

### For Deployment

1. **Physical security** - Control USB access
2. **Write-protect media** if possible (CD-ROM ideal)
3. **Verify after writing** - checksum the USB
4. **Document process** for incident response
5. **Plan key recovery** procedures
6. **Test regularly** - ensure media still boots

## Audit Trail

The script creates:
```
out/esp/secureboot-bootable.img.sha256  # Checksum of output
out/esp/BUILD_UUID                       # Unique build identifier
keys/*.crt                               # Public certificates for audit
```

**Recommendations:**
- Log all script executions
- Record ISO source and checksum used
- Document who created what media when
- Keep build artifacts for forensics

## Compliance Considerations

### NIST Guidelines

The script aligns with:
- **NIST SP 800-147** - BIOS Protection Guidelines
- **NIST SP 800-155** - BIOS Integrity Measurement
- **NIST SP 800-147B** - BIOS Protection Guidelines for Servers

### Industry Standards

- **UEFI Specification 2.9** - SecureBoot implementation
- **TCG PC Client Platform** - Trusted boot
- **Microsoft SecureBoot Requirements** - For Windows compatibility

## Security Checklist

Before deployment:
- [ ] Keys backed up securely
- [ ] Keys encrypted at rest
- [ ] Appropriate file permissions set
- [ ] ISO source verified and trusted
- [ ] Build process documented
- [ ] Output checksummed and verified
- [ ] Boot tested in safe environment
- [ ] Recovery procedure documented
- [ ] Incident response plan ready
- [ ] Key rotation schedule defined

## Incident Response

If keys are compromised:

1. **Immediate:**
   - Stop using compromised keys
   - Generate new keys
   - Recreate all boot media
   - Audit all systems for unauthorized signatures

2. **Short term:**
   - Enroll new keys on all systems
   - Revoke old keys if possible
   - Investigate scope of compromise

3. **Long term:**
   - Review key management procedures
   - Improve security controls
   - Document lessons learned

## Questions and Concerns

For security-related questions:
1. Review this document
2. Check UEFI specification
3. Consult SecureBoot best practices
4. Open GitHub issue with `security` label

**Do NOT:**
- Share private keys publicly
- Post keys in issues or pull requests
- Publish key material in documentation

## References

- [UEFI Specification](https://uefi.org/specifications)
- [NIST SP 800-147](https://csrc.nist.gov/publications/detail/sp/800-147/final)
- [Microsoft SecureBoot](https://docs.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-secure-boot)
- [Linux Foundation Shim](https://github.com/rhboot/shim)

---

**Remember:** Security is a process, not a product. This tool provides the foundation, but proper operational security depends on your deployment practices.
