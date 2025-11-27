# UUEFI Enhanced Features

## Overview

UUEFI (Universal UEFI Diagnostic Application) has been significantly enhanced to provide comprehensive EFI variable management and security analysis capabilities. Version 3.0.0 transforms UUEFI from a diagnostic tool into a powerful full BIOS replacement that provides complete control over system configuration, similar to traditional BIOS interfaces but with modern UEFI capabilities.

## What's New in Version 3.0.0

### Revolutionary Features

🔥 **Complete BIOS Replacement** - UUEFI now functions as a full-featured BIOS that runs AFTER your hardware BIOS, giving you a second layer of configuration control.

🔥 **Variable Editing** - Edit ANY tweakable EFI variable with intelligent type detection and safety protections.

🔥 **ESP Configuration Management** - View and manage configuration files directly from the EFI System Partition.

🔥 **Nuclear Wipe System** - The ultimate malware response tool that can completely wipe your system including BIOS settings and disk data.

🔥 **Enhanced Descriptions** - Every variable now includes a human-readable description explaining its purpose.

## Core Features

## Core Features

### 1. Complete EFI Variable Enumeration with Descriptions

UUEFI reads **ALL** EFI variables present in the system using the UEFI Runtime Services `GetNextVariableName()` API. This provides complete visibility into:

- Boot configuration variables (with detailed descriptions)
- Security keys and settings (with safety explanations)
- Hardware-specific configurations (with purpose identification)
- Vendor-specific features (marked as editable)
- Unknown or undocumented variables (flagged for investigation)

**NEW in v3.0:** Each variable now includes:
- **Human-readable description** - Explains what the variable does
- **Editability flag** - Indicates if it's safe to modify
- **Type detection** - Automatically identifies data types (boolean, numeric, string)
- **Current value display** - Shows actual value in multiple formats

Example:
```
Variable: MyAsusAutoInstall [EDITABLE]
  Size: 1 bytes, Attr: 0x00000007
  Description: MyASUS software auto-install setting (editable)
  Current Value: 1 (Enabled)
```

### 2. Variable Editing System

UUEFI v3.0 introduces a comprehensive variable editing system that allows safe modification of EFI variables:

**Supported Operations:**
- Set variable to 0 (Disable)
- Set variable to 1 (Enable)
- Delete variable completely
- View current value in multiple formats (hex, decimal, boolean)

**Safety Features:**
- Security variables (PK, KEK, db, dbx, SecureBoot) are **protected** from modification
- Critical boot variables (BootOrder, BootCurrent) are **protected**
- Vendor-specific variables are **marked as editable**
- Double confirmation required before any changes
- Clear warnings about potential impacts

**Example Editable Variables:**
- Boot animations (disable for faster boot)
- Vendor bloatware (MyASUS, Armoury Crate auto-install)
- Cloud recovery settings
- OEM telemetry features
- Hardware feature toggles

### 3. ESP Configuration Viewer and Manager

Access and view configuration files stored in the EFI System Partition:

**Accessible Files:**
- `/EFI/PhoenixGuard/config.txt` - PhoenixGuard settings
- `/EFI/PhoenixGuard/ESP_UUID.txt` - ESP identification
- `/EFI/BOOT/grub.cfg` - GRUB configuration
- `/EFI/ubuntu/grub.cfg` - Ubuntu-specific GRUB
- `loader/loader.conf` - systemd-boot configuration

**Features:**
- Preview file contents (first 512 bytes)
- Show file sizes and locations
- Read-only viewing for safety
- Instructions for editing from OS

**Companion Tool:**
```bash
# Extract all ESP configurations to JSON
sudo bash scripts/esp-config-extract.sh

# Output: esp_configs_YYYYMMDD_HHMMSS.json
```

### 4. Nuclear Wipe System ☢️

The "nuclear option" for severe malware infections or system decommissioning:

**What It Does:**
1. **Wipes Vendor Variables** - Removes all vendor-specific settings
2. **Clears Boot Entries** - Removes non-current boot entries (preserves active boot)
3. **Provides Disk Wipe Instructions** - Guides you through using nwipe
4. **Full NVRAM Reset** - Returns BIOS to near-factory state

**Safety Measures:**
- Requires multiple confirmations
- Preserves current boot entry (so you can still boot)
- Protects critical security variables
- Provides clear next-steps documentation

**Integration with nwipe:**
```bash
# Launch nuclear wipe from OS
sudo bash scripts/nuclear-wipe.sh

# Options:
# 1. Interactive mode (recommended)
# 2. Quick wipe (zeros only)
# 3. DoD Short (3 passes)
# 4. PRNG Stream (cryptographically secure)
```

**Use Cases:**
- ✓ Severe malware/rootkit infection
- ✓ Security breach response
- ✓ System decommissioning
- ✓ Complete fresh start needed

### 5. Smart Variable Categorization

UUEFI now reads **ALL** EFI variables present in the system using the UEFI Runtime Services `GetNextVariableName()` API. This provides complete visibility into:

- Boot configuration variables
- Security keys and settings
- Hardware-specific configurations
- Vendor-specific features
- Unknown or undocumented variables

The enumeration process automatically categorizes variables by type for easier navigation.

### 5. Smart Variable Categorization

Variables are automatically classified into categories:

- **Boot Configuration**: BootOrder, Boot####, BootCurrent, BootNext, etc.
- **Security**: SecureBoot, PK, KEK, db, dbx, SetupMode
- **Hardware**: Hardware-specific configuration variables
- **Vendor-Specific**: OEM and vendor custom variables
- **Unknown**: Uncategorized variables for investigation

### 6. Security Heuristics Engine

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

### 7. Interactive Menu System

A user-friendly menu allows navigation through variable categories:

```
╔════════════════════════════════════════════╗
║    UUEFI INTERACTIVE MENU v3.0            ║
║    Full BIOS-like Configuration           ║
╚════════════════════════════════════════════╝

═══ Variable Management ═══
1. View All Variables
2. View Boot Configuration Variables
3. View Security Variables
4. View Vendor-Specific Variables
5. Show Security Report (Suspicious Activity)
6. Edit Variable (Advanced)
7. Re-scan Variables

═══ System Configuration ═══
8. View ESP Configuration Files
9. Export Variable List

═══ Advanced/Nuclear Options ═══
N. ☢ Nuclear Wipe System (EXTREME CAUTION)

Q. Return to Firmware
```

### 8. Security Analysis Report

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

### 9. Variable Editing and Management (v3.0)

**NEW in v3.0:** Comprehensive variable editing system with intelligent type detection:

**Editing Capabilities:**
- Set variable to 0 (Disable feature)
- Set variable to 1 (Enable feature)
- Delete variable completely
- View current value in multiple formats (hex, decimal, boolean)

**Safety Features:**
- Security variables (PK, KEK, db, dbx, SecureBoot) are **completely protected**
- Critical boot variables (BootOrder, BootCurrent) are **protected**
- Vendor-specific variables marked as **editable**
- Double confirmation required before any changes
- Clear warnings about potential impacts
- Shows current value before modification

**Type Detection:**
- Boolean (1 byte): Shows Enabled/Disabled
- Numeric (2/4 bytes): Shows decimal value
- Large data: Shows hex preview
- String data: Attempts to decode

**Use Cases:**
- Disable vendor bloatware features (MyASUS, Armoury Crate)
- Turn off OEM telemetry and cloud features
- Disable boot animations for faster boot
- Remove unwanted hardware features
- Test firmware behavior with different configurations

### 10. ESP Configuration Viewer (v3.0)

**NEW in v3.0:** View configuration files directly from the EFI System Partition:

**Accessible Locations:**
- `/EFI/PhoenixGuard/` - PhoenixGuard configurations
- `/EFI/BOOT/` - Primary boot configurations
- `/EFI/ubuntu/` - Ubuntu-specific configs
- `loader/` - systemd-boot configurations

**Features:**
- Preview file contents (first 512 bytes)
- Display file sizes and metadata
- Read-only viewing for safety
- Instructions for OS-based editing

**Companion Tool:**
```bash
# Extract all ESP configurations to JSON
sudo bash scripts/esp-config-extract.sh

# Output: esp_configs_YYYYMMDD_HHMMSS.json
```

The extraction tool creates a structured JSON file containing:
- All configuration file paths
- File sizes and editability status
- Content previews (up to 1KB)
- Boot configuration variables
- EFI variable information

### 11. Nuclear Wipe System ☢️ (v3.0)

**NEW in v3.0:** Complete system wipe for severe malware infections:

**Phase 1: Vendor Variable Wipe**
- Identifies all vendor-specific variables
- Safely removes editable vendor configs
- Preserves critical system variables
- Reports number of items wiped

**Phase 2: Boot Entry Cleanup**
- Removes all boot entries except current
- Preserves ability to boot system
- Cleans boot configuration
- Maintains boot functionality

**Phase 3: Disk Wiping Integration**
- Provides nwipe integration instructions
- Guides to recovery environment
- Explains wipe methods (DoD, PRNG, etc.)
- Links to companion script

**Safety Measures:**
- Multiple confirmation prompts (N → Y required)
- Phase-based execution with status reporting
- Preserves current boot entry (ensures bootability)
- Clear rollback instructions provided
- Complete summary of actions taken

**Integration Script:**
```bash
# Launch nuclear wipe from OS
sudo bash scripts/nuclear-wipe.sh

# Options:
# 1. Interactive nwipe (recommended)
# 2. Quick wipe (zeros only, fast)
# 3. DoD Short (3 passes, government standard)
# 4. PRNG Stream (cryptographically secure)
```

**Use Cases:**
- Severe rootkit/bootkit infection response
- Security breach remediation
- System decommissioning
- Complete fresh start required
- Vendor bloatware removal

### 12. Real-Time Variable Re-scanning

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
- View detailed variable information with descriptions
- Edit variables (v3.0)
- Access security reports
- View ESP configurations (v3.0)
- Manage vendor variables
- Access nuclear wipe system (v3.0)

### Advanced Features (v3.0)

**Variable Editing:**
```
1. Select option 6 from menu
2. Review editable variables list
3. Note variable index
4. Choose modification type (0/1/delete)
5. Confirm changes
6. Reboot to apply
```

**ESP Configuration:**
```
1. Select option 8 from menu
2. View available config files
3. Read content previews
4. For editing: boot to OS and use extraction script
```

**Nuclear Wipe:**
```
1. Select option N from menu
2. Read all warnings carefully
3. Confirm with 'N' then 'Y'
4. Review phase-by-phase execution
5. Follow post-wipe instructions
```

### Security Report Mode

Press **R** to view the security analysis report:
- See all suspicious findings
- Review severity levels
- Understand potential risks
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

### Vendor Feature Management (v3.0 Enhanced)

- **Disable OEM bloatware** - MyASUS, Armoury Crate auto-install
- **Turn off telemetry** - Cloud recovery, usage tracking
- **Customize hardware behavior** - Animations, power profiles
- **Optimize boot configuration** - Faster boot times
- **Edit tweakable settings** - Direct variable modification

### System Recovery (v3.0 New)

- **Malware/rootkit response** - Nuclear wipe for severe infections
- **BIOS reset** - Factory default restoration
- **Boot repair** - Clear corrupted entries
- **Decommissioning** - Secure data erasure

### Troubleshooting

- Investigate boot issues
- Check variable corruption
- Verify firmware settings
- Debug hardware configuration
- View ESP configurations

### Research & Analysis

- Study vendor implementations
- Reverse engineer firmware features
- Document OEM-specific variables
- Build compatibility databases
- Extract configuration profiles

## Version History

### 3.0.0 (Current - Code First Update)

**Major Feature Release: Full BIOS Replacement**

New Features:
- ✅ **Variable Editing System** - Edit any tweakable EFI variable with type detection
- ✅ **Human-Readable Descriptions** - Every variable includes purpose explanation
- ✅ **Editability Flags** - Clear marking of safely editable variables
- ✅ **ESP Configuration Viewer** - View config files from EFI System Partition
- ✅ **Nuclear Wipe System** - Complete system wipe for malware response
- ✅ **Enhanced Menu** - 9 options with categorized sections
- ✅ **Variable Export** - Instructions and tools for data export
- ✅ **Companion Scripts** - ESP extraction and nwipe integration

Improvements:
- Enhanced menu structure with sections
- Better variable categorization
- Improved safety protections
- Comprehensive documentation
- Real-world use case examples

**Philosophy:** "Turn UUEFI into a real full on bios that happens after the bios"

### 2.0.0 (Previous)

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

- **Variable backup/restore** - Save/restore variable state
- **JSON export from UUEFI** - Export directly from firmware (currently requires OS tools)
- **Custom heuristics rules** - User-defined security checks
- **Variable comparison** - Compare states between boots
- **PhoenixGuard integration** - Submit findings to central database
- **Network analysis** - Remote attestation and reporting
- **Variable fuzzing** - Security testing capabilities
- **Automated remediation** - Suggested fixes for issues
- **Numeric input improvements** - Better keyboard input handling
- **Variable history tracking** - Track changes over time
- **ESP file editing** - Direct editing from UUEFI (carefully)
- **Backup before wipe** - Automatic state backup before nuclear wipe

## Contributing

When contributing to UUEFI:

1. **Minimal changes** - Surgical modifications only
2. **Safety first** - Protect critical variables
3. **Clear warnings** - User must understand risks
4. **Documentation** - Update all relevant docs
5. **Testing** - Test on QEMU and real hardware if possible
6. **Heuristics** - Add comprehensive checks with rationale
7. **Descriptions** - Add human-readable variable descriptions

### Areas for Contribution

- **Variable descriptions** - Add more detailed descriptions for vendor-specific variables
- **Security heuristics** - New detection patterns for suspicious activity
- **Hardware support** - Document variables for different OEMs (ASUS, Dell, HP, Lenovo)
- **Use cases** - Real-world examples and solutions
- **Testing** - Verify on different hardware platforms
- **Documentation** - Improve guides and troubleshooting

## License

Part of PhoenixBoot/PhoenixGuard project.
Licensed under Apache License 2.0.
See main LICENSE file for details.

## References

- [UEFI Specification](https://uefi.org/specifications)
- [EDK2 Documentation](https://github.com/tianocore/tianocore.github.io/wiki/EDK-II)
- [PhoenixBoot Main Documentation](../README.md)
- [UEFI Variable Services](https://uefi.org/specs/UEFI/2.10/08_Services_Runtime_Services.html#variable-services)
