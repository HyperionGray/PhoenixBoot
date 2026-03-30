# Validation Scripts

Scripts for validating system security and detecting threats.

## Security Validation

- `secure-env-check.sh` - Comprehensive security environment check
- `validate-keys.sh` - Validate SecureBoot keys
- `validate-esp.sh` - Validate ESP configuration
- `verify-sb.sh` - Verify SecureBoot status
- `verify-esp-robust.sh` - Robust ESP verification

## Threat Detection

- `scan-bootkits.sh` - Scan for bootkit infections
- `detect_bootkit.py` - Python-based bootkit detection
- `analyze_firmware_baseline.py` - Analyze firmware baseline
- `../../utils/hardware_compatibility_probe.py` - Host compatibility probe for PhoenixBoot prerequisites

## Baseline Verification

- `baseline-verify.sh` - Verify against baseline

## Usage

```bash
# Run comprehensive security check
./pf.py secure-env

# Or run script directly
bash ./scripts/validation/secure-env-check.sh

# Scan for bootkits
./scripts/validation/scan-bootkits.sh

# Probe host compatibility (writes JSON report under out/reports/)
./pf.py hardware-compat-probe
```
