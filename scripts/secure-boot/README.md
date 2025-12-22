# SecureBoot Scripts

Scripts for managing SecureBoot keys, enrollment, and enablement.

## Key Generation

- `generate-sb-keys.sh` - Generate SecureBoot keys (PK, KEK, db)
- `sb_keys_custom.sh` - Custom SecureBoot key generation
- `create-auth-files.sh` - Create authentication files
- `der-extract.sh` - Extract DER format from certificates

## Key Enrollment

- `enroll-secureboot.sh` - Enroll SecureBoot keys
- `enroll-secureboot-nosudo.sh` - Enroll SecureBoot keys (no sudo)

## 🆕 Secure Boot Enablement (Double Kexec Method)

- `check-secureboot-status.sh` - **NEW**: Check Secure Boot status and enablement capability
- `enable-secureboot-kexec.sh` - **NEW**: Enable Secure Boot via double kexec method

### Features

**check-secureboot-status.sh** checks:
- UEFI system compatibility
- Current Secure Boot state (enabled/disabled)
- Setup Mode status (can enroll custom keys)
- Kernel configuration for BIOS flashing
- Kexec availability
- Provides actionable recommendations

**enable-secureboot-kexec.sh** implements:
- Double kexec workflow (no power cycle reboots)
- Kernel switching without rebooting
- Framework for Secure Boot enablement
- Safety checks and prerequisites validation

### Usage

```bash
# Check Secure Boot status
./pf.py secureboot-check

# Or run directly
./scripts/secure-boot/check-secureboot-status.sh

# Enable Secure Boot via double kexec (advanced)
sudo ./pf.py secureboot-enable-kexec

# Or run directly
sudo ./scripts/secure-boot/enable-secureboot-kexec.sh
```

### Documentation

See [Secure Boot Enablement via Kexec Guide](../../docs/SECUREBOOT_ENABLEMENT_KEXEC.md) for:
- Complete workflow explanation
- Step-by-step instructions
- Kernel configuration profiles
- Troubleshooting guide
- Security considerations

## Key Management

- `keys-centralize.sh` - Centralize key management

## Documentation

- `generate-secureboot-instructions.sh` - Generate SecureBoot instructions
- `create-secureboot-instructions.sh` - Create SecureBoot setup guide

## Traditional Usage

```bash
# Generate SecureBoot keys
./pf.py secure-keygen

# Or run script directly
./scripts/secure-boot/generate-sb-keys.sh

# Create authentication files
./pf.py secure-make-auth
```

