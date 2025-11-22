# UUEFI Enhanced Features

## Overview

UUEFI (Universal UEFI Diagnostic Application) has been significantly enhanced to provide comprehensive EFI variable management and security analysis capabilities. Version 2.0.0 transforms UUEFI from a simple diagnostic tool into a powerful firmware-level security and configuration utility.

## New Features

### 1. Complete EFI Variable Enumeration

UUEFI now reads **ALL** EFI variables present in the system using the UEFI Runtime Services `GetNextVariableName()` API. This provides complete visibility into:

- Boot configuration variables
- Security keys and settings
- Hardware-specific configurations
- Vendor-specific features
- Unknown or undocumented variables

The enumeration process automatically categorizes variables by type for easier navigation.

### 2. Smart Variable Categorization

Variables are automatically classified into categories:

- **Boot Configuration**: BootOrder, Boot####, BootCurrent, BootNext, etc.
- **Security**: SecureBoot, PK, KEK, db, dbx, SetupMode
- **Hardware**: Hardware-specific configuration variables
- **Vendor-Specific**: OEM and vendor custom variables
- **Unknown**: Uncategorized variables for investigation

### 3. Security Heuristics Engine

UUEFI implements intelligent heuristics to detect suspicious or anomalous variables:

#### Detection Rules:

1. **Unusually Large Variables**
   - Flags variables exceeding 32KB (excluding db/dbx which legitimately can be large)
   - Helps identify potential data hiding or firmware implants
   - Severity: MEDIUM

2. **Boot Variables with Wrong Attributes**
   - Verifies boot variables have proper NV+BS+RT attributes
   - Detects tampering or malformed boot entries
   - Severity: MEDIUM

3. **Security Variables Without Authentication**
   - Checks that security-critical variables require authenticated writes
   - Identifies potential Secure Boot bypass vulnerabilities
   - Severity: HIGH

4. **Suspicious Variable Names**
   - Scans for keywords like "Debug", "Test", "Backdoor", "Hidden"
   - Detects development/testing variables left in production firmware
   - Severity: MEDIUM

### 4. Interactive Menu System

A user-friendly menu allows navigation through variable categories:

```
╔════════════════════════════════════════════╗
║        UUEFI INTERACTIVE MENU             ║
╚════════════════════════════════════════════╝

1. View All Variables
2. View Boot Configuration Variables
3. View Security Variables
4. View Vendor-Specific Variables
5. Show Security Report (Suspicious Activity)
6. Toggle Vendor Variable (Advanced)
7. Re-scan Variables
Q. Return to Firmware
```

### 5. Security Analysis Report

Generates a comprehensive security report showing:

- Total variables analyzed
- Number of suspicious items found
- Severity breakdown (High/Medium/Low)
- Detailed findings with explanations
- Recommendations for remediation

Example output:
```
╔════════════════════════════════════════════╗
║     SECURITY ANALYSIS REPORT              ║
╚════════════════════════════════════════════╝

Total Variables Analyzed: 147
Suspicious Items Found: 3

Severity Breakdown:
  🔴 HIGH:   1 issues
  🟡 MEDIUM: 2 issues

Detailed Findings:
═══════════════════

[1] Potentially vulnerable security variable (Severity: HIGH)
    Security variable 'SetupMode' may be writable without authentication

[2] Large variable detected (Severity: MEDIUM)
    Variable 'VendorConfig' has unusual size: 65536 bytes
```

### 6. Variable Toggle/Management

For vendor-specific variables, UUEFI allows safe toggling to disable unwanted features:

**Safety Features:**
- Security variables (PK, KEK, db, dbx, SecureBoot) are **protected** from modification
- Critical boot variables (BootOrder, BootCurrent) are **protected** from modification
- Only vendor-specific variables can be modified
- User confirmation required before any changes
- Clear warnings displayed before modification

**Use Cases:**
- Disable vendor bloatware features
- Turn off OEM telemetry
- Disable unwanted hardware features
- Test firmware behavior with different configurations

### 7. Real-Time Variable Re-scanning

Variables can be re-enumerated without rebooting to capture:
- Variables created at runtime
- Dynamic configuration changes
- Variables that only appear after certain conditions

## Usage

### Basic Diagnostic Mode

Run UUEFI like any EFI application. It will:
1. Display standard system information (firmware, memory, security status)
2. Automatically enumerate all variables
3. Run security heuristics
4. Display quick summary of findings

### Interactive Mode

Press **M** to enter the interactive menu:
- Browse variables by category
- View detailed variable information
- Access security reports
- Manage vendor variables

### Security Report Mode

Press **R** to view the security analysis report:
- See all suspicious findings
- Review severity levels
- Understand potential risks

## Technical Details

### Data Structures

```c
typedef struct {
  CHAR16 Name[MAX_VARIABLE_NAME_SIZE];
  EFI_GUID VendorGuid;
  UINTN DataSize;
  UINT32 Attributes;
  VARIABLE_CATEGORY Category;
  BOOLEAN IsSuspicious;
  CHAR16 SuspicionReason[256];
} VARIABLE_INFO;
```

### Key Functions

- `EnumerateAllVariables()` - Scans all EFI variables
- `CategorizeVariable()` - Classifies variables by type
- `CheckVariableHeuristics()` - Runs security checks
- `DisplaySecurityReport()` - Shows findings
- `ShowInteractiveMenu()` - User interface
- `ToggleVariable()` - Safely modifies vendor variables

### Memory Management

- Dynamic allocation for variable storage (up to 500 variables)
- Proper cleanup on exit
- No memory leaks

## Building

### EDK2 Version

```bash
cd staging/src
chmod +x ../tools/build-uuefi.sh
../tools/build-uuefi.sh
```

Output: `UUEFI.efi`

### GNU-EFI Version

Build with GNU-EFI toolchain for alternative compatibility.

Output: `UUEFI-gnuefi.efi`

## Testing

### QEMU Testing

```bash
./pf.py test-qemu-uuefi
```

### Real Hardware

1. Copy `UUEFI.efi` to your ESP:
   ```bash
   sudo cp UUEFI.efi /boot/efi/EFI/PhoenixGuard/
   ```

2. Boot directly or create a boot entry:
   ```bash
   sudo efibootmgr --create --disk /dev/sda --part 1 \
     --label "UUEFI Diagnostics" \
     --loader '\EFI\PhoenixGuard\UUEFI.efi'
   ```

3. Select from boot menu or use BootNext:
   ```bash
   sudo ./scripts/uuefi-apply.sh
   sudo reboot
   ```

## Security Considerations

### What UUEFI Does

- ✅ Reads all variables (read-only operation, safe)
- ✅ Analyzes variable properties (non-invasive)
- ✅ Detects suspicious patterns (helpful for security)
- ✅ Allows toggling vendor variables (with safeguards)

### What UUEFI Does NOT Do

- ❌ Does not modify security variables (PK, KEK, db, dbx)
- ❌ Does not modify critical boot variables
- ❌ Does not bypass Secure Boot protections
- ❌ Does not persist changes without user confirmation
- ❌ Does not automatically remediate issues

### Best Practices

1. **Review First**: Always review the security report before making changes
2. **Understand Impact**: Know what vendor variables do before toggling them
3. **Test in VM**: Test variable changes in QEMU before running on real hardware
4. **Backup**: Keep backups of critical system configuration
5. **Document**: Record any changes made for troubleshooting

## Use Cases

### Security Auditing

- Scan for unexpected or suspicious variables
- Verify Secure Boot configuration
- Detect firmware tampering
- Identify development/test variables in production

### Vendor Feature Management

- Disable OEM bloatware
- Turn off telemetry
- Customize hardware behavior
- Optimize boot configuration

### Troubleshooting

- Investigate boot issues
- Check variable corruption
- Verify firmware settings
- Debug hardware configuration

### Research & Analysis

- Study vendor implementations
- Reverse engineer firmware features
- Document OEM-specific variables
- Build compatibility databases

## Version History

### 2.0.0 (Current)

- Complete EFI variable enumeration
- Smart categorization system
- Security heuristics engine
- Interactive menu interface
- Security analysis reporting
- Safe variable toggling
- Both EDK2 and GNU-EFI builds

### 1.0.0 (Original)

- Basic system information display
- Firmware vendor and version
- Memory map summary
- Boot configuration
- Security status

## Future Enhancements

Potential improvements for future versions:

- Variable backup/restore functionality
- Export variable database to JSON/XML
- Custom heuristics rules engine
- Variable comparison between boots
- Integration with PhoenixGuard reporting
- Network-based analysis submission
- Variable fuzzing capabilities
- Automated remediation suggestions

## Contributing

When contributing to UUEFI:

1. Maintain minimal changes philosophy
2. Add comprehensive heuristics with clear rationale
3. Protect critical variables from modification
4. Include clear user warnings
5. Test on both QEMU and real hardware
6. Update this documentation

## License

Part of PhoenixBoot/PhoenixGuard project.
See main LICENSE file.

## References

- [UEFI Specification](https://uefi.org/specifications)
- [EDK2 Documentation](https://github.com/tianocore/tianocore.github.io/wiki/EDK-II)
- [PhoenixBoot Main Documentation](../README.md)
- [UEFI Variable Services](https://uefi.org/specs/UEFI/2.10/08_Services_Runtime_Services.html#variable-services)
