# UUEFI v3.1.0 - Debug Diagnostics Mode

## Overview

UUEFI v3.1.0 introduces comprehensive debug diagnostics capabilities that dump EVERYTHING from your UEFI firmware environment. This mode is designed for deep system analysis, security auditing, malware investigation, and discovering hidden IOCTLs or protocols.

## What's New in v3.1.0

### 🔍 Debug Diagnostics Menu

A new "Debug Diagnostics" mode accessible from the main menu that provides:

1. **Complete Variable Dump** - ALL EFI variables with full data (hex + ASCII)
2. **Protocol Database** - ALL protocols and handles (find hidden IOCTLs)
3. **Configuration Tables** - ALL system tables (ACPI, SMBIOS, etc.)
4. **Detailed Memory Map** - ALL memory regions with attributes
5. **Full System Dump** - Everything above in one comprehensive dump

## Main Menu Access

From the UUEFI main menu, press **D** to enter Debug Diagnostics:

```
Options:
  M - Enter Interactive Menu (View & Manage Variables)
  R - Show Security Report
  D - 🔍 Debug Diagnostics (EVERYTHING - ALL vars, logs, protocols!)
  N - ☢ Nuclear Wipe Menu (EXTREME)
  Q - Return to Firmware
```

## Debug Menu Options

### Option 1: Complete Variable Dump

**Purpose**: Dump ALL EFI variable data in hex and ASCII format

**What It Shows**:
- Variable name
- GUID (globally unique identifier)
- Size in bytes
- Attributes (NV, BS, RT, AUTH, etc.)
- Complete hex dump of data
- ASCII interpretation of data
- Human-readable descriptions

**Example Output**:
```
[42] MyasusAutoInstall
  GUID: 1ab12345-6789-1234-5678-9abcdef01234
  Size: 5 bytes
  Attributes: 0x00000007
  Flags: NV BS RT 
  Description: ASUS: MyASUS software auto-install
  Hex dump (5 bytes):
    0000: 01 00 00 00 00                                   |.....|
```

**Use Cases**:
- Analyze variable contents for security research
- Detect malware hidden in variables
- Reverse engineer vendor-specific data formats
- Document firmware behavior
- Export complete variable state for analysis

**Performance**: May take several minutes for systems with 500+ variables

### Option 2: Protocol Database (IOCTLs)

**Purpose**: Enumerate ALL protocols installed in the system to find hidden IOCTLs

**What It Shows**:
- All handles in the system
- All protocols attached to each handle
- Protocol GUIDs
- Handle addresses

**Example Output**:
```
Found 234 handles in system

Handle[0]: 0x6F8D4000 (3 protocols)
  Protocol[0]: 09576e91-6d3f-11d2-8e39-00a0c969723b
  Protocol[1]: 0379be4e-d706-437d-b037-edb82fb772a4
  Protocol[2]: 5b1b31a1-9562-11d2-8e3f-00a0c969723b

Handle[1]: 0x6F8D5000 (2 protocols)
  Protocol[0]: 387477c1-69c7-11d2-8e39-00a0c969723b
  Protocol[1]: 09576e91-6d3f-11d2-8e39-00a0c969723b
...
```

**Known Protocol GUIDs**:
Some common protocols you'll see:
- `09576e91-6d3f-11d2-8e39-00a0c969723b` - EFI_DEVICE_PATH_PROTOCOL
- `5b1b31a1-9562-11d2-8e3f-00a0c969723b` - EFI_PCI_IO_PROTOCOL
- `387477c1-69c7-11d2-8e39-00a0c969723b` - EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
- `964e5b22-6459-11d2-8e39-00a0c969723b` - EFI_BLOCK_IO_PROTOCOL
- `8868e871-e4f1-11d3-bc22-0080c73c8881` - EFI_ACPI_TABLE_PROTOCOL

**Use Cases**:
- Discover hidden or undocumented protocols
- Find vendor-specific IOCTLs
- Identify rootkit-installed protocols
- Map the complete protocol landscape
- Research firmware capabilities

**What Are IOCTLs in UEFI?**
In UEFI, protocols serve a similar purpose to IOCTLs (Input/Output Control) in operating systems. They provide interfaces to:
- Hardware devices
- Firmware services
- Vendor-specific features
- Boot services
- Runtime services

### Option 3: Configuration Tables

**Purpose**: Display ALL system configuration tables

**What It Shows**:
- ACPI tables (for OS integration)
- SMBIOS tables (hardware information)
- Device tree tables
- Vendor-specific tables
- Table addresses in memory

**Example Output**:
```
Number of Configuration Tables: 7

[0] GUID: eb9d2d30-2d88-11d3-9a16-0090273fc14d
    Table Address: 0x7DEE5000
    Type: ACPI 1.0 Table

[1] GUID: 8868e871-e4f1-11d3-bc22-0080c73c8881
    Table Address: 0x7DEE6000
    Type: ACPI 2.0+ Table

[2] GUID: eb9d2d31-2d88-11d3-9a16-0090273fc14d
    Table Address: 0x7DEE4000
    Type: SMBIOS 2.x Table
...
```

**Known Table GUIDs**:
- `eb9d2d30-2d88-11d3-9a16-0090273fc14d` - ACPI 1.0
- `8868e871-e4f1-11d3-bc22-0080c73c8881` - ACPI 2.0+
- `eb9d2d31-2d88-11d3-9a16-0090273fc14d` - SMBIOS 2.x
- `f2fd1544-9794-4a2c-992e-e5bbcf20e394` - SMBIOS 3.x

**Use Cases**:
- Locate ACPI tables for OS analysis
- Find SMBIOS data for hardware inventory
- Verify table integrity
- Detect table manipulation
- Research firmware structure

### Option 4: Detailed Memory Map

**Purpose**: Show ALL memory regions with complete details

**What It Shows**:
- Memory type (Reserved, LoaderCode, BSCode, RTCode, Conventional, etc.)
- Physical start address
- Virtual start address (if mapped)
- Number of pages (4KB each)
- Memory attributes (WB, WT, UC, WC, WP, RP, XP, RO, etc.)

**Example Output**:
```
Memory Map Entries: 156
Descriptor Version: 0x1
Descriptor Size: 48 bytes

Type                 PhysicalStart       VirtualStart        Pages       Attributes
═══════════════════════════════════════════════════════════════════════════════════
Reserved             0000000000000000    0000000000000000         1    000000000000000f
LoaderCode           0000000000001000    0000000000000000        20    000000000000000f
LoaderData           0000000000015000    0000000000000000        41    000000000000000f
BSCode               0000000000044000    0000000000000000       156    000000000000000f
BSData               0000000000100000    0000000000000000      1024    000000000000000f
Conventional         0000000000500000    0000000000000000     32768    000000000000000f
RTCode               0000000008100000    0000000008100000        64    800000000000000f
RTData               0000000008140000    0000000008140000        32    800000000000000f
...
```

**Memory Types**:
- **Reserved**: Reserved by firmware
- **LoaderCode**: Boot loader code
- **LoaderData**: Boot loader data
- **BSCode**: Boot Services code
- **BSData**: Boot Services data
- **RTCode**: Runtime Services code
- **RTData**: Runtime Services data
- **Conventional**: Free memory
- **Unusable**: Defective memory
- **ACPIReclaim**: ACPI data (can be reclaimed)
- **ACPINVS**: ACPI NVS (preserved across S3)
- **MMIO**: Memory-mapped I/O
- **MMIOPort**: Memory-mapped I/O port space
- **PalCode**: PAL code (Itanium)
- **Persistent**: Persistent memory

**Memory Attributes** (hex flags):
- Bit 0: UC (Uncacheable)
- Bit 1: WC (Write Combining)
- Bit 2: WT (Write Through)
- Bit 3: WB (Write Back) - Most common
- Bit 4: UCE (Uncacheable, Exported)
- Bit 12: RP (Read Protected)
- Bit 13: WP (Write Protected)
- Bit 14: XP (Execute Protected)
- Bit 15: RO (Read Only)
- Bit 63: Runtime bit

**Use Cases**:
- Analyze memory layout
- Detect memory holes
- Find firmware code regions
- Locate runtime services
- Identify MMIO regions
- Detect memory anomalies
- Research bootkit locations

### Option 5: Full System Dump

**Purpose**: Execute ALL of the above diagnostics in sequence

**What It Does**:
1. Complete Variable Dump
2. Protocol Database enumeration
3. Configuration Tables display
4. Detailed Memory Map

**Confirmation Required**: Press 'Y' to confirm due to the extensive time required

**Estimated Time**: 
- Small system (< 200 variables): 5-10 minutes
- Medium system (200-400 variables): 10-20 minutes
- Large system (400+ variables): 20-30 minutes

**Output Size**: Can be several megabytes of data

**Use Cases**:
- Complete system forensics
- Pre-disposal audit
- Malware investigation
- Firmware research
- Security audit baseline
- System documentation

## Performance and Limitations

### Performance Notes

1. **Variable Dump**: 
   - Pauses every 5 variables for user control
   - Press any key to continue, 'Q' to cancel
   - Truncates data display at 256 bytes per variable (full size still shown)

2. **Protocol Database**: 
   - Pauses every 10 handles for user control
   - Can be cancelled mid-enumeration

3. **Configuration Tables**: 
   - Fast, typically completes in seconds
   - No pagination needed

4. **Memory Map**: 
   - Pauses every 20 entries for user control
   - Typical systems have 100-200 entries

### Output Limitations

1. **Variable Data**: 
   - Display truncated at 256 bytes per variable
   - Full size reported in header
   - Prevents overwhelming output for large variables

2. **Protocol GUIDs**: 
   - Only GUID displayed, not full protocol contents
   - Use protocol GUID to lookup specification

3. **Memory Addresses**: 
   - Virtual addresses may be 0 if not yet mapped
   - Physical addresses are always valid

### System Impact

**Safe Operations**:
- All debug operations are READ-ONLY
- No modification to any system state
- No writes to variables or memory
- Safe to run on production systems

**Resource Usage**:
- Allocates temporary memory for dumps
- Memory is freed after each operation
- No persistent resource consumption

## Security Implications

### What Debug Mode Reveals

**Sensitive Information Exposed**:
1. **Security Keys** (in variables):
   - Secure Boot keys (PK, KEK, db, dbx)
   - Encryption keys
   - TPM measurements
   - Passwords (if stored improperly)

2. **Hardware Details**:
   - Complete system configuration
   - Memory layout
   - Device addresses
   - Firmware version details

3. **Vendor Secrets**:
   - Proprietary configuration data
   - Vendor-specific protocols
   - OEM customizations
   - Debug features

**Privacy Considerations**:
- Variable dumps may contain personally identifying information
- Serial numbers and asset tags may be exposed
- User settings and preferences visible
- Use caution when sharing dumps publicly

### Security Use Cases

**Malware Detection**:
1. Look for suspicious variables with unusual names
2. Check for unexpected protocols
3. Verify configuration table integrity
4. Analyze memory layout for anomalies

**Rootkit Detection**:
1. Compare protocol list against known good baseline
2. Look for injected protocols
3. Check for hooked protocol functions
4. Verify runtime service addresses

**Supply Chain Verification**:
1. Document complete firmware state
2. Create baseline for future comparison
3. Verify no tampering during shipping
4. Audit vendor customizations

**Incident Response**:
1. Capture complete system state
2. Export data for offline analysis
3. Compare with known good system
4. Document evidence chain

## Use Cases and Examples

### 1. Malware Investigation

**Scenario**: Suspect firmware-level malware

**Steps**:
1. Boot UUEFI
2. Press 'D' for Debug Diagnostics
3. Option 5: Full System Dump
4. Review variable dump for suspicious entries
5. Check protocol database for unknown protocols
6. Compare with known clean system

**Red Flags**:
- Variables with names like "Debug", "Test", "Backdoor"
- Unusual protocols not in UEFI specification
- Modified security variables
- Unexpected ACPI tables

### 2. Vendor Bloatware Removal

**Scenario**: Want to disable OEM features

**Steps**:
1. Boot UUEFI
2. Press 'D' for Debug Diagnostics
3. Option 1: Complete Variable Dump
4. Identify vendor-specific variables
5. Note variable names and contents
6. Return to main menu
7. Use variable editing to disable features

**Common Vendor Variables**:
- ASUS: `MyasusAutoInstall`, `AsusAnimationSetupConfig`
- Dell: `DellRecovery`, `DellSupport`
- HP: `HPCertainView`, `HPPrivacy`
- Lenovo: `LenovoVantage`, `SystemUpdate`

### 3. Firmware Research

**Scenario**: Reverse engineer firmware behavior

**Steps**:
1. Boot UUEFI on test system
2. Full System Dump to capture baseline
3. Boot OS and modify settings
4. Reboot to UUEFI
5. Full System Dump again
6. Compare dumps to see what changed

**Analysis**:
- Diff the variable dumps
- Identify which variables store which settings
- Document vendor-specific formats
- Build comprehensive database

### 4. Security Audit

**Scenario**: Corporate security compliance

**Steps**:
1. Boot UUEFI
2. Full System Dump
3. Save output to trusted USB drive
4. Analyze offline:
   - Verify Secure Boot configuration
   - Check for unauthorized variables
   - Validate configuration tables
   - Review memory map for anomalies
5. Generate compliance report

**Compliance Checks**:
- Secure Boot enabled and configured
- No suspicious variables
- All variables match approved list
- No unknown protocols
- Memory map matches expected layout

### 5. Discovering Hidden Features

**Scenario**: Find undocumented BIOS features

**Steps**:
1. Boot UUEFI
2. Protocol Database dump
3. Google each unknown protocol GUID
4. Check UEFI specification
5. Identify vendor-specific protocols
6. Test protocols using custom UEFI application

**Common Hidden Features**:
- Vendor-specific overclocking
- Debug interfaces
- Manufacturing test modes
- Hidden BIOS options
- Diagnostic tools

## Output Interpretation Guide

### Reading Variable Dumps

**Header Information**:
```
[42] MyasusAutoInstall
```
- `[42]` = Variable index in enumeration
- `MyasusAutoInstall` = Variable name

**GUID Format**:
```
GUID: 1ab12345-6789-1234-5678-9abcdef01234
```
- Standard UUID format
- Use to identify variable namespace

**Attribute Flags**:
```
Flags: NV BS RT 
```
- `NV` = Non-Volatile (persists across reboots)
- `BS` = BootService Access (accessible during boot)
- `RT` = Runtime Access (accessible by OS)
- `HW_ERR` = Hardware Error Record
- `AUTH_WR` = Authenticated Write
- `TIME_AUTH` = Time-based Authentication
- `APPEND` = Append-only

**Hex Dump**:
```
0000: 01 00 00 00 00                                   |.....|
```
- Left: Offset in hex
- Middle: Data bytes in hex
- Right: ASCII interpretation (`.` for non-printable)

### Reading Protocol GUIDs

**Lookup Resources**:
1. UEFI Specification (uefi.org)
2. EDK2 source code (github.com/tianocore/edk2)
3. GNU-EFI headers
4. Google search

**Common Patterns**:
- `09576e91-...` series: Core UEFI protocols
- `387477c1-...` series: Legacy BIOS protocols
- Vendor GUIDs: Check OEM documentation

### Reading Memory Types

**Critical Types for Security**:
- **RTCode/RTData**: Can be accessed by OS (potential attack surface)
- **ACPINVS**: Preserved across sleep (rootkit persistence)
- **Reserved**: Often firmware code/data
- **Persistent**: NVRAM-backed memory

**Security Concerns**:
- Excessive RTCode/RTData may indicate bloatware
- Unexpected Reserved regions may be hidden firmware
- Unusual MMIO ranges may be malicious devices

## Troubleshooting

### Problem: Output Scrolls Too Fast

**Solution**: 
- Use pagination (automatic every 5/10/20 items)
- Press any key to continue
- Press 'Q' to cancel anytime

### Problem: System Hangs During Dump

**Possible Causes**:
1. Variable read timeout
2. Firmware bug
3. Corrupted variable

**Solutions**:
- Hard reboot (hold power button)
- Try individual dumps instead of full dump
- Update firmware before trying again

### Problem: Can't Read Certain Variables

**Possible Causes**:
1. Protected by firmware
2. Locked variables
3. Insufficient permissions

**Normal Behavior**:
- Some variables are read-protected
- Will show "[Failed to read]" in output
- Not a bug, security feature

### Problem: Protocol GUIDs Don't Match Known Protocols

**Possible Reasons**:
1. Vendor-specific protocols
2. Beta/experimental protocols
3. Malicious protocols (rare)

**Actions**:
1. Google the GUID
2. Check OEM documentation
3. Compare with known good system
4. Report to PhoenixGuard project

## Best Practices

### Data Collection

1. **Always create baseline**:
   - Run full dump on clean system
   - Save output to trusted location
   - Use for future comparisons

2. **Document everything**:
   - Note system make/model
   - Record firmware version
   - Include date/time of dump
   - Save UUEFI version used

3. **Protect sensitive data**:
   - Dumps may contain keys/passwords
   - Sanitize before sharing publicly
   - Store securely
   - Use encryption

### Analysis Workflow

1. **Initial Survey**:
   - Quick variable dump (option 1)
   - Scroll through for obvious issues
   - Note anything suspicious

2. **Deep Dive**:
   - Full system dump (option 5)
   - Save to file for analysis
   - Compare with baseline
   - Research unknown GUIDs

3. **Verification**:
   - Reboot and dump again
   - Verify consistency
   - Check for changes
   - Document findings

### Security Guidelines

1. **Trusted Environment**:
   - Only run on systems you control
   - Don't run on production servers without approval
   - Use test systems for experimentation

2. **Data Handling**:
   - Treat dumps as sensitive data
   - Don't share without sanitizing
   - Encrypt stored dumps
   - Delete when no longer needed

3. **Incident Response**:
   - Capture evidence immediately
   - Don't modify system after dump
   - Follow chain of custody
   - Document everything

## Integration with PhoenixGuard Ecosystem

### Workflow Integration

1. **Initial Assessment**:
   - Use UUEFI Debug Mode for initial scan
   - Identify issues
   - Export data

2. **Analysis**:
   - Import to PhoenixGuard tools
   - Compare with known good baseline
   - Generate report

3. **Remediation**:
   - Use UUEFI variable editing
   - Or use PhoenixGuard recovery tools
   - Or use Nuclear Wipe if needed

4. **Verification**:
   - Re-scan with Debug Mode
   - Verify remediation
   - Create new baseline

### Future Enhancements

Planned for v3.2.0+:
1. Export to JSON/XML
2. Automated baseline comparison
3. PhoenixGuard cloud integration
4. Anomaly detection AI
5. Protocol fuzzing
6. Memory forensics
7. Automated report generation

## Technical Details

### Implementation

**Variable Dumping**:
- Uses `GetVariable()` UEFI Runtime Service
- Allocates temporary buffer per variable
- Frees memory after each dump
- Handles errors gracefully

**Protocol Enumeration**:
- Uses `LocateHandleBuffer()` with `AllHandles`
- Calls `ProtocolsPerHandle()` for each handle
- No protocol data accessed (GUID only)
- Safe read-only operation

**Configuration Tables**:
- Reads `gST->ConfigurationTable` array
- No table data accessed
- Only metadata displayed

**Memory Map**:
- Uses `GetMemoryMap()` Boot Service
- Allocates buffer with extra space
- Displays all descriptors
- No memory data accessed

### Code Structure

**New Functions in UUEFI.c**:
- `DumpVariableData()` - Hex dump formatter
- `ShowDebugVariableDump()` - Variable enumeration
- `ShowProtocolDatabase()` - Protocol/handle enumeration
- `ShowConfigurationTables()` - Config table display
- `ShowDetailedMemoryMap()` - Memory map formatter
- `ShowDebugMenu()` - Main debug menu

**New Functions in UUEFI-gnuefi.c**:
- `DumpVariableDataGnuefi()` - GNU-EFI version
- `ShowDebugVariableDumpGnuefi()` - GNU-EFI version
- `ShowProtocolDatabaseGnuefi()` - GNU-EFI version
- `ShowConfigurationTablesGnuefi()` - GNU-EFI version
- `ShowDebugMenuGnuefi()` - GNU-EFI version

### Dependencies

**EDK2 Version**:
- No additional dependencies
- Uses standard UEFI services
- Compatible with UEFI 2.0+

**GNU-EFI Version**:
- Requires gnu-efi library
- Uses uefi_call_wrapper
- Compatible with gnu-efi 3.0+

## References

### UEFI Specifications
- [UEFI Specification 2.10](https://uefi.org/specifications)
- [Runtime Services](https://uefi.org/specs/UEFI/2.10/08_Services_Runtime_Services.html)
- [Boot Services](https://uefi.org/specs/UEFI/2.10/07_Services_Boot_Services.html)
- [Protocols](https://uefi.org/specs/UEFI/2.10/12_Protocols.html)

### Tools and Resources
- [EDK2 Documentation](https://github.com/tianocore/tianocore.github.io/wiki)
- [GNU-EFI Library](https://sourceforge.net/projects/gnu-efi/)
- [PhoenixBoot Project](https://github.com/P4X-ng/PhoenixBoot)
- [ACPI Specification](https://uefi.org/specifications)
- [SMBIOS Specification](https://www.dmtf.org/standards/smbios)

### Research Papers
- "Attacking UEFI Boot Script"
- "UEFI Rootkits: Myths and Reality"
- "Analyzing UEFI Malware"
- "UEFI Firmware Fuzzing"

## Changelog

### v3.1.0 (2025-12-05)
- ✨ Added Debug Diagnostics Menu
- ✨ Added Complete Variable Dump with hex/ASCII
- ✨ Added Protocol Database enumeration
- ✨ Added Configuration Tables display
- ✨ Added Detailed Memory Map (EDK2 only)
- ✨ Added Full System Dump option
- 🔧 Updated banner to reflect debug capabilities
- 📝 Created comprehensive debug documentation

### v3.0.0 (Previous)
- Variable management and security analysis
- Nuclear Wipe menu
- Variable descriptions
- Interactive menu

## Support

For issues, questions, or contributions:
- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Pull Requests**: https://github.com/P4X-ng/PhoenixBoot/pulls
- **Documentation**: See docs/ directory

## License

Part of PhoenixBoot/PhoenixGuard project. See main LICENSE file.

---

**⚠ WARNING**: Debug dumps contain sensitive information including security keys, hardware details, and system configuration. Handle with care and never share publicly without sanitizing.

**🔥 PhoenixGuard UUEFI v3.1.0 - Debug Everything Mode - ALL Vars, ALL Logs, ALL Protocols!**
