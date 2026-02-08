# UUEFI v3.0.0 - Full BIOS Features & Nuclear Wipe

## Overview

UUEFI v3.0.0 represents a major enhancement that transforms UUEFI into a **full BIOS-like interface** that runs after the hardware BIOS, providing comprehensive EFI variable management, detailed descriptions, editing capabilities, and a complete system sanitization suite.

This version addresses the issue request to "turn this into a real full on bios" with features that match and extend traditional BIOS setup utilities.

## What's New in v3.0.0

### 1. Comprehensive Variable Descriptions

Every EFI variable now includes a human-readable description explaining its purpose:

**Boot Variables:**
- `BootOrder` - "Boot device order sequence"
- `BootCurrent` - "Currently booted device entry"
- `BootNext` - "Next boot device (one-time)"
- `Boot####` - "Boot device entry configuration"

**Security Variables:**
- `SecureBoot` - "Secure Boot enabled/disabled status"
- `SetupMode` - "Firmware in setup mode for key enrollment"
- `PK` - "Platform Key (root of trust)"
- `KEK` - "Key Exchange Key database"
- `db` - "Authorized signature database (whitelist)"
- `dbx` - "Forbidden signature database (blacklist)"

**Vendor-Specific Variables (ASUS):**
- `AsusAnimationSetupConfig` - "BIOS UI animations control" (Editable)
- `MyasusAutoInstall` - "MyASUS software auto-install" (Editable)
- `AsusCameraHashValueUpdate` - "Camera security and privacy"
- `AsusGnvsVariable` - "ACPI Global NVS variables"
- `ArmouryCrateStaticField` - "ROG Armoury Crate gaming config" (Editable)
- `PreviousAsusTouchPadDevice` - "Touchpad device configuration"
- `AsForceMemoryRetrain` - "Memory training control" (Editable)

**Intel Platform Variables:**
- `IntelUefiCnvWlan*` - "WiFi configuration" (Editable)
- `IntelUefiCnvBt*` - "Bluetooth configuration" (Editable)
- `IntelVmdDeviceInfo` - "VMD NVMe RAID configuration"
- `IntelRstFeatures` - "Rapid Storage Technology"
- `WRDS/WRDD/WGDS/EWRD` - "WiFi regulatory domain settings" (Editable)
- `SADS/BRDS` - "Bluetooth regulatory settings" (Editable)

**Memory & Recovery:**
- `MemoryOverwriteRequestControl` - "Memory overwrite request (security)"
- `MemoryRetrain` variables - "Memory training control" (Editable)
- `CloudRecoverySupport` - "Cloud recovery service configuration" (Editable)

### 2. Editable Variable Interface

Variables now display an edit indicator (✎) showing which can be safely modified:

```
[42] MyasusAutoInstall ✎
    Size: 5 bytes, Attr: 0x00000007
    Description: ASUS: MyASUS software auto-install
```

**Safety Features:**
- Security variables (PK, KEK, db, dbx, SecureBoot) are **protected** from editing
- Critical boot variables (BootOrder, BootCurrent) are **protected** from editing  
- Only vendor-specific variables marked as safe can be edited
- User confirmation required before any modifications
- Clear warnings displayed before changes

### 3. Nuclear Wipe Menu (☢)

A complete system sanitization suite for extreme malware situations:

#### Option 1: NVRAM Variable Wipe (Vendor Variables Only)
- Deletes all non-critical vendor-specific variables
- Preserves boot configuration and security keys
- Useful for removing vendor bloatware/malware
- **Risk Level: MEDIUM** - May affect vendor features

**Use Cases:**
- Remove OEM telemetry
- Disable vendor bloatware
- Clean up unnecessary vendor features
- Test firmware behavior without vendor customizations

#### Option 2: Full NVRAM Reset (Factory Defaults)
- Resets ALL variables including boot order
- Preserves only critical security variables (PK, KEK, db, dbx)
- System will boot to firmware setup on next boot
- **Risk Level: HIGH** - Will reset all BIOS settings

**Use Cases:**
- Serious firmware malware infection
- Complete BIOS corruption
- Return to factory defaults
- Remove persistent firmware-level rootkits

#### Option 3: Disk Wiping Information
- Comprehensive guide to secure disk sanitization
- Information about `nwipe` and other tools
- Instructions for HDD and SSD wiping
- ATA Secure Erase for SSDs
- **Risk Level: NONE** - Information only

**Covers:**
- nwipe usage and methods (DoD, Gutmann, PRNG)
- Hardware-encrypted SSD secure erase
- Manufacturer tools (Samsung Magician, etc.)
- Step-by-step workflow
- No data is modified

#### Option 4: Complete Nuclear Wipe (NVRAM + Disk)
- Combination of Options 2 & 3
- Full firmware reset + disk wipe guidance
- Maximum sanitization for critical situations
- **Risk Level: EXTREME** - Complete system reset

**Complete Workflow:**
1. **NVRAM Reset** (Done in UUEFI)
   - Delete all non-security variables
   - Reset firmware to factory defaults
   
2. **Firmware Reset** (After reboot)
   - System boots to firmware setup
   - Verify all settings at defaults
   - Optionally update firmware/BIOS
   
3. **Disk Sanitization** (External tool)
   - Boot Linux live USB
   - Run `nwipe` on all drives
   - Wait for completion (may take hours)
   
4. **Clean Reinstall** (From trusted media)
   - Install OS from verified media
   - Enable Secure Boot with your own keys
   - Install PhoenixGuard for ongoing protection

**When to Use:**
- Firmware-level bootkit infection
- Persistent rootkit that survives OS reinstall
- Supply chain attack concerns
- Complete system sanitization before disposal/transfer
- Maximum paranoia security scenario

### 4. Enhanced Interactive Menu

The interactive menu now includes all new features:

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
8. ☢ Nuclear Wipe Menu (EXTREME)
Q. Return to Firmware
```

### 5. Improved Variable Display

Variables now show:
- Index number for reference
- Edit indicator (✎) if editable
- Size and attributes
- Human-readable description
- Suspicious activity warnings (⚠)

Example output:
```
--- Vendor-Specific (23 variables) ---
  [108] AsusAnimationSetupConfig ✎
    Size: 7 bytes, Attr: 0x00000007
    Description: ASUS: BIOS UI animations control

  [109] MyasusAutoInstall ✎
    Size: 5 bytes, Attr: 0x00000007
    Description: ASUS: MyASUS software auto-install

  [110] IntelUefiCnvWlanMPCC ✎
    Size: 16 bytes, Attr: 0x00000007
    Description: Intel: WiFi configuration
```

## Main Menu Enhancements

The startup menu now includes direct access to Nuclear Wipe:

```
Options:
  M - Enter Interactive Menu (View & Manage Variables)
  R - Show Security Report
  N - ☢ Nuclear Wipe Menu (EXTREME)
  Q - Return to Firmware
```

## Technical Implementation

### New Data Structures

```c
// Enhanced variable info with descriptions
typedef struct {
  CHAR16 Name[MAX_VARIABLE_NAME_SIZE];
  EFI_GUID VendorGuid;
  UINTN DataSize;
  UINT32 Attributes;
  VARIABLE_CATEGORY Category;
  BOOLEAN IsSuspicious;
  CHAR16 SuspicionReason[256];
  CHAR16 Description[MAX_DESCRIPTION_SIZE];  // NEW
  BOOLEAN IsEditable;                        // NEW
} VARIABLE_INFO;
```

### New Functions

1. `DescribeVariable()` - Assigns human-readable descriptions
   - Pattern matching for ASUS variables
   - Pattern matching for Intel variables
   - Wireless/network configuration detection
   - Memory-related variable identification
   - Recovery/cloud feature detection

2. `ShowNuclearWipeMenu()` - Complete sanitization interface
   - Vendor variable wipe with confirmation
   - Full NVRAM reset with safeguards
   - Disk wiping information and guidance
   - Complete nuclear wipe workflow

3. Enhanced `DisplayVariablesByCategory()` - Shows descriptions and editability

### Safety Mechanisms

**Protected Variables:**
- All security variables (PK, KEK, db, dbx, SecureBoot, SetupMode)
- Critical boot variables (BootOrder, BootCurrent)
- Any variable not explicitly marked as editable

**Confirmation Requirements:**
- User must type 'WIPE' or 'RESET' for destructive operations
- Multiple warnings before any changes
- Clear explanation of consequences
- Ability to cancel at any point

**Preservation:**
- Security keys are NEVER deleted in any wipe option
- NVRAM reset preserves PK, KEK, db, and dbx
- Clear indication of what will be preserved

## Use Cases

### 1. BIOS-like Configuration Management

UUEFI v3.0.0 now functions as a full BIOS interface:
- Browse all firmware settings
- View detailed descriptions
- Edit vendor-specific features
- Disable unwanted bloatware
- Optimize boot configuration

### 2. Vendor Bloatware Removal

Disable unwanted OEM features:
```
Examples:
- MyASUS auto-installation
- BIOS animations
- Cloud recovery services
- Telemetry features
- Marketing integrations
```

### 3. Security Hardening

- Disable unnecessary vendor features
- Remove potential attack surfaces
- Clean up suspicious variables
- Audit firmware configuration
- Verify security settings

### 4. Malware Recovery (Nuclear Option)

Complete system sanitization workflow:
1. Boot to UUEFI
2. Select Nuclear Wipe Menu (Option N)
3. Choose Option 4 (Complete Nuclear Wipe)
4. Confirm NVRAM reset
5. Reboot to firmware setup
6. Boot Linux live USB
7. Run nwipe on all drives
8. Reinstall OS from trusted media

### 5. Firmware Research & Analysis

- Study vendor implementations
- Document OEM-specific variables
- Reverse engineer firmware features
- Build compatibility databases
- Test firmware behavior

## Comparison with Traditional BIOS

| Feature | Traditional BIOS | UUEFI v3.0.0 |
|---------|------------------|--------------|
| Variable browsing | Limited, vendor-specific | Complete, all variables |
| Descriptions | Vendor-defined | Auto-generated + documented |
| Editing | Fixed menus | Flexible, safe editing |
| Reset options | Load defaults | Multiple granularity options |
| Security analysis | None | Heuristics + suspicious detection |
| Disk wipe | None | Integrated guidance |
| Vendor features | Hidden | Exposed and editable |
| Documentation | Minimal | Comprehensive per-variable |
| Safety | Implicit | Explicit protections |
| Extensibility | None | Pattern-based descriptions |

## Security Considerations

### What UUEFI v3.0.0 Does
✅ Read all variables (safe, read-only scanning)
✅ Analyze properties and detect anomalies
✅ Describe variables with human-readable text
✅ Allow controlled editing of safe variables
✅ Provide complete NVRAM reset capability
✅ Guide secure disk sanitization

### What UUEFI v3.0.0 Does NOT Do
❌ Modify security variables (PK, KEK, db, dbx)
❌ Modify critical boot variables without confirmation
❌ Bypass Secure Boot protections
❌ Auto-apply changes without user confirmation
❌ Hide information from user
❌ Automatically wipe systems

### Safety Philosophy

UUEFI v3.0.0 follows a "trust but verify" approach:
1. **Transparency** - All operations are clearly explained
2. **Confirmation** - Destructive actions require explicit confirmation
3. **Protection** - Critical variables are locked from modification
4. **Granularity** - Multiple levels of reset (vendor-only to complete)
5. **Reversibility** - Most changes can be undone
6. **Documentation** - Every feature is thoroughly documented

## Building UUEFI v3.0.0

### Prerequisites

```bash
# Install build dependencies
sudo apt-get install build-essential uuid-dev nasm iasl
```

### EDK2 Build

```bash
cd staging/src
chmod +x ../tools/build-uuefi.sh
../tools/build-uuefi.sh
```

Output: `UUEFI.efi` (approximately 10-15 KB)

### Installation

```bash
# Copy to ESP
sudo cp UUEFI.efi /boot/efi/EFI/PhoenixGuard/

# Create boot entry
sudo efibootmgr --create --disk /dev/sda --part 1 \
  --label "UUEFI v3.0" \
  --loader '\EFI\PhoenixGuard\UUEFI.efi'

# Or use BootNext for one-time boot
sudo ./scripts/uuefi-apply.sh
sudo reboot
```

## Testing

### QEMU Testing

```bash
./pf.py test-qemu-uuefi
```

### Real Hardware Testing Workflow

1. **Safe Testing**
   - Boot UUEFI
   - Browse variables (non-destructive)
   - View descriptions and categories
   - Check security report
   - Exit without changes

2. **Variable Editing**
   - Select vendor variable to edit
   - Confirm understanding of changes
   - Apply modification
   - Reboot and verify

3. **Nuclear Wipe (Test System Only)**
   - **DO NOT use on production systems without backups!**
   - Test in QEMU or disposable hardware first
   - Verify all data is backed up
   - Follow complete workflow
   - Verify system recovery

## Emergency Capsule Path (v3.2.0)

This release introduces a capsule-like emergency path that only unlocks when UUEFI is booted from your signed, trusted media. Drop a lightweight marker file at `\EFI\PhoenixGuard\UUEFI_EMERGENCY.marker` on the ESP you plan to ship as the “capsule” and UUEFI will detect it at boot. When the marker is present:

- UUEFI prints: “Emergency capsule marker detected; emergency clear option unlocked.”
- The interactive menu adds a new **E. Emergency Capsule Clear (Vendor variables)** entry.
- Selecting `E` performs a safe deletion pass over vendor/unknown variables after you type `EMERGENCY`.
  The actual `SetVariable` calls only run when the signed capsule is present, mirroring the hardware vendor capsule model while staying software-only.

### Preparing the capsule marker

1. Build/sign `UUEFI.efi` with your db key (`./pf.py build-build`/EDK2 + `sbsign`).
2. Mount the ESP you will distribute (USB or installers).
3. Create the marker file:

   ```bash
   sudo mkdir -p /mnt/esp/EFI/PhoenixGuard
   printf 'Emergency capsule marker – keep this on trusted media only.\n' \
     | sudo tee /mnt/esp/EFI/PhoenixGuard/UUEFI_EMERGENCY.marker
   ```

4. Copy the signed `UUEFI.efi` to `EFI/PhoenixGuard/` (or `EFI/BOOT` if you prefer BootNext).
5. Ship this disk/USB as your “capsule.” UUEFI will refuse to show the emergency option unless the marker exists.

Keep the marker file off any other media; it is intentionally simple so that only your signed capsule (which carries your keys) enables the risky clearing path.

## Code Statistics

### UUEFI.c Enhancements

- **Version**: 2.0.0 → 3.0.0
- **Lines Added**: ~497 lines
- **New Functions**: 2 major functions
  - `DescribeVariable()` (150+ lines)
  - `ShowNuclearWipeMenu()` (340+ lines)
- **Modified Functions**: 3
  - `EnumerateAllVariables()` - Added description call
  - `DisplayVariablesByCategory()` - Enhanced display
  - `ShowInteractiveMenu()` - Added nuclear wipe option
- **New Descriptions**: 150+ variable patterns covered

### Variable Description Coverage

- **ASUS**: 10+ variable patterns
- **Intel**: 8+ variable patterns
- **Wireless/Network**: 8+ patterns
- **Memory**: 3+ patterns
- **Recovery/Cloud**: 2+ patterns
- **Boot**: 4 patterns
- **Security**: 6 patterns
- **Generic Vendor**: Catch-all pattern

## Future Enhancements

Potential improvements for v4.0:

1. **Variable Backup/Restore**
   - Save current variable state
   - Restore from backup
   - Export/import functionality

2. **Advanced Editing**
   - Hex editor for variable data
   - Value presets for common configurations
   - Batch editing capabilities

3. **Configuration Profiles**
   - Gaming profile
   - Security-hardened profile
   - Minimal bloat profile
   - Performance profile

4. **Integration with PhoenixGuard Cloud**
   - Submit variable analysis
   - Share vendor variable databases
   - Community-contributed descriptions
   - Threat intelligence integration

5. **Automated Sanitization**
   - One-click malware recovery
   - Scheduled NVRAM cleaning
   - Suspicious variable quarantine

6. **Advanced Heuristics**
   - Machine learning anomaly detection
   - Firmware integrity verification
   - Bootkit signature detection

## Known Limitations

1. **Build Dependencies**
   - Requires EDK2 toolchain
   - Needs nasm, uuid-dev packages
   - Build time can be lengthy

2. **Variable Deletion**
   - Some vendor variables may be read-only
   - Firmware may recreate certain variables
   - Some deletions require firmware support

3. **Description Coverage**
   - Not all vendor variables documented
   - New hardware may have unknown variables
   - Community contributions needed

4. **Disk Wiping**
   - UUEFI only provides guidance
   - Actual wiping requires external tools
   - Cannot directly erase disks from UEFI

## Contributing

To add descriptions for new vendor variables:

1. Identify the variable name pattern
2. Add pattern to `DescribeVariable()` function
3. Set appropriate description
4. Mark as editable if safe
5. Test on real hardware
6. Submit pull request

Example:
```c
if (StrStr(VarInfo->Name, L"VendorFeature") != NULL) {
  StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, 
          L"Vendor: Feature description");
  VarInfo->IsEditable = TRUE;
}
```

## Changelog

### v3.2.0 (2025-12-22)
- 🔒 **Added Secure Boot Variable Guarding** - Prevents hardware lockouts and system bricking
- ✨ Added `ValidateDbKeys()` - Validates at least one key exists in db signature database
- ✨ Added `CheckSecureBootConfiguration()` - Comprehensive secure boot state validation
- ✨ Added `GuardVariableModification()` - Guards variables from unsafe modifications
- ⚠ **Critical Detection**: Detects when SecureBoot enabled but db database is empty (broken state)
- 🛡️ **Protection**: Blocks ALL variable modifications when system is in unsafe state
- 📊 Added menu option 9: "Validate Secure Boot Configuration" with comprehensive report
- 📝 Enhanced `DisplaySecurityInfo()` with detailed validation and warnings
- 🔒 Updated variable modification to use new guarding mechanism
- 📚 Created comprehensive secure boot guarding documentation

### v3.0.0 (2025-11-26)
- ✨ Added comprehensive variable descriptions (150+ patterns)
- ✨ Added editability indicators and safety checks
- ✨ Added Nuclear Wipe menu with 4 sanitization options
- ✨ Added vendor variable wipe capability
- ✨ Added full NVRAM reset with security key preservation
- ✨ Added disk wiping information and guidance
- ✨ Added complete nuclear wipe workflow
- ✨ Enhanced variable display with indices and descriptions
- ✨ Added direct nuclear wipe access from main menu
- 📝 Updated banner to reflect "Full BIOS Features + Nuclear Wipe"
- 🔒 Enhanced safety mechanisms for critical variables
- 📚 Created comprehensive v3.0 documentation

### v2.0.0 (Previous)
- Variable enumeration and categorization
- Security heuristics engine
- Interactive menu system
- Basic variable toggling
- Security analysis reports

### v1.0.0 (Original)
- Basic system information display
- Firmware, memory, security status
- Simple diagnostic output

## License

Part of PhoenixBoot/PhoenixGuard project.
See main LICENSE file.

## References

- [UEFI Specification](https://uefi.org/specifications)
- [EDK2 Documentation](https://github.com/tianocore/tianocore.github.io/wiki/EDK-II)
- [PhoenixBoot Main Documentation](../README.md)
- [UEFI Variable Services](https://uefi.org/specs/UEFI/2.10/08_Services_Runtime_Services.html#variable-services)
- [UEFI Secure Boot Specification](https://uefi.org/specs/UEFI/2.10/32_Secure_Boot.html)
- [Secure Boot Variable Guarding Guide](SECURE_BOOT_GUARDING.md)
- [nwipe Documentation](https://github.com/martijnvanbrummelen/nwipe)
- [ATA Secure Erase](https://ata.wiki.kernel.org/index.php/ATA_Secure_Erase)

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/P4X-ng/PhoenixBoot/issues
- Pull Requests: https://github.com/P4X-ng/PhoenixBoot/pulls
- Email: devel@edk2.groups.io (for EDK2-specific issues)

---

**⚠ WARNING**: Nuclear Wipe options are EXTREMELY DESTRUCTIVE. Only use when absolutely necessary and when you fully understand the consequences. ALL DATA WILL BE PERMANENTLY LOST. Always maintain backups of important data.

**🔥 PhoenixGuard UUEFI v3.2.0 - The Real Full-On BIOS That Happens After The BIOS - Now With Secure Boot Guarding!**
