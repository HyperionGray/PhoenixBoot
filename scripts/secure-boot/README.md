# SecureBoot Scripts

Scripts for managing SecureBoot keys and enrollment.

## Key Generation

- `generate-sb-keys.sh` - Generate SecureBoot keys (PK, KEK, db)
- `sb_keys_custom.sh` - Custom SecureBoot key generation
- `create-auth-files.sh` - Create authentication files
- `der-extract.sh` - Extract DER format from certificates

## Key Enrollment

- `enroll-secureboot.sh` - Enroll SecureBoot keys
- `enroll-secureboot-nosudo.sh` - Enroll SecureBoot keys (no sudo)

## Key Management

- `keys-centralize.sh` - Centralize key management

## Documentation

- `generate-secureboot-instructions.sh` - Generate SecureBoot instructions
- `create-secureboot-instructions.sh` - Create SecureBoot setup guide

## Usage

```bash
# Generate SecureBoot keys
./pf.py secure-keygen

# Or run script directly
./scripts/secure-boot/generate-sb-keys.sh

# Create authentication files
./pf.py secure-make-auth
```
