# Validation Scripts

Scripts for validating system security and detecting threats.

## Security Validation

- `secure-env-check.sh` - Comprehensive security environment check
- `hardware-compat-check.sh` - Host hardware compatibility probe for PhoenixBoot workflows
- `validate-keys.sh` - Validate SecureBoot keys
- `validate-esp.sh` - Validate ESP configuration
- `verify-sb.sh` - Verify SecureBoot status
- `verify-esp-robust.sh` - Robust ESP verification

## Threat Detection

- `scan-bootkits.sh` - Scan for bootkit infections
- `detect_bootkit.py` - Python-based bootkit detection
- `analyze_firmware_baseline.py` - Analyze firmware baseline

## Baseline Verification

- `baseline-verify.sh` - Verify against baseline

## Usage

```bash
# Run comprehensive security check
./pf.py secure-env

# Probe hardware compatibility before advanced workflows
./pf.py hardware-compat

# Or run script directly
bash ./scripts/validation/secure-env-check.sh

# Strict mode (warnings treated as non-zero exit)
bash ./scripts/validation/hardware-compat-check.sh --strict

# Scan for bootkits
./scripts/validation/scan-bootkits.sh
```
