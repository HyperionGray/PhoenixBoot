# UUEFI v3.0 - Full BIOS Configuration Guide

## Introduction

UUEFI v3.0 represents a major evolution in firmware-level system control. It's now a complete BIOS replacement that runs **after** your hardware BIOS, providing a second layer of configuration and control that traditional BIOS interfaces lack.

Think of it as "BIOS²" - all the power of a traditional BIOS interface, but with the flexibility and modern capabilities of UEFI, plus advanced security and recovery features.

## Key Capabilities

### 🎯 What Makes UUEFI v3.0 Special

1. **Post-BIOS Configuration** - Runs after hardware initialization, giving you access to change settings that your OEM BIOS might not expose
2. **Full Variable Control** - Edit ANY EFI variable that your motherboard exposes (with intelligent safety guards)
3. **ESP Management** - View and understand boot configuration files without booting to an OS
4. **Nuclear Recovery** - The ultimate malware response tool for complete system wipe and restoration
5. **Vendor Bloatware Control** - Disable OEM software auto-installers and telemetry at the firmware level

## Getting Started

### Installation

```bash
# Install UUEFI to your ESP
sudo ./pf.py uuefi-install

# Boot into UUEFI once (for testing)
sudo ./pf.py uuefi-apply
sudo reboot
```

### First Boot

When you boot into UUEFI for the first time, you'll see:

```
╔════════════════════════════════════════════╗
║  🔥 PhoenixGuard UUEFI 3.0.0              ║
║  Universal UEFI Diagnostic & Config Tool  ║
║  Enhanced: Full BIOS-like Configuration   ║
║  • Variable Editing • ESP Config • Wipe   ║
╚════════════════════════════════════════════╝
```

UUEFI will automatically:
1. Display firmware and system information
2. Enumerate all EFI variables (may take 10-30 seconds)
3. Run security heuristics to detect suspicious variables
4. Show a quick summary of findings

Then you can press **M** to enter the interactive menu.

## Interactive Menu Guide

### Main Menu Options

```
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

### Option Details

#### 1. View All Variables
Shows every EFI variable on your system with:
- Variable name
- Size and attributes
- Description (what it does)
- Editability status
- Security warnings if suspicious

Example output:
```
--- Boot Configuration (12 variables) ---
  Boot0000 [EDITABLE]
    Size: 128 bytes, Attr: 0x00000007
    Description: Boot device entry configuration

--- Vendor-Specific (45 variables) ---
  MyAsusAutoInstall [EDITABLE]
    Size: 1 bytes, Attr: 0x00000007
    Description: MyASUS software auto-install setting (editable)
```

#### 2-4. Filtered Variable Views
Same as option 1, but filtered by category (Boot, Security, Vendor) for easier navigation.

#### 5. Security Report
Shows suspicious variables detected by UUEFI's heuristics engine:
- Unusually large variables (possible data hiding)
- Boot variables with wrong attributes (possible tampering)
- Security variables without authentication (bypass vulnerabilities)
- Variables with suspicious names (Debug, Test, Backdoor, Hidden)

#### 6. Edit Variable (Advanced)
**⚠️ USE WITH CAUTION**

This allows you to modify EFI variables. Safety features:
- Security variables are **completely protected**
- Critical boot variables are **protected**
- Double confirmation required
- Shows current value before editing

Common use cases:
```bash
# Disable MyASUS auto-install
Variable: MyAsusAutoInstall
Current Value: 1 (Enabled)
→ Select option 1 (Set to 0 - Disable)

# Disable boot animations (faster boot)
Variable: AsusAnimationSetupConfig
Current Value: 1 (Enabled)
→ Select option 1 (Set to 0 - Disable)
```

#### 7. Re-scan Variables
Useful if:
- You made changes and want to verify
- System created new runtime variables
- You want a fresh scan after suspicion of changes

#### 8. View ESP Configuration Files
Shows configuration files from your EFI System Partition:
- PhoenixGuard configs
- GRUB configuration
- systemd-boot settings
- Boot loader entries

Displays first 512 bytes of each file for preview.

**Tip:** For editing ESP configs, use the companion script:
```bash
sudo bash scripts/esp-config-extract.sh
# Outputs: esp_configs_YYYYMMDD_HHMMSS.json
```

#### 9. Export Variable List
Provides summary and instructions for exporting complete variable data to JSON format using the OS-based tools.

#### N. Nuclear Wipe System ☢️
**⚠️⚠️⚠️ EXTREME CAUTION ⚠️⚠️⚠️**

This is the "nuclear option" for severe malware infections. It will:

**Phase 1: Reset Vendor Variables**
- Wipes all vendor-specific settings
- Removes OEM bloatware configurations
- Clears telemetry settings

**Phase 2: Clear Boot Entries**
- Removes all boot entries EXCEPT the current one
- Preserves ability to boot back to system
- Cleans boot configuration

**Phase 3: Disk Wiping Instructions**
- Provides guidance for using nwipe
- Explains integration with recovery environment
- Shows commands for secure disk wiping

**When to Use:**
- Severe rootkit/bootkit infection confirmed
- System completely compromised
- Preparing for decommissioning
- Starting completely fresh required

**What You'll Need After:**
- BIOS reconfiguration (factory defaults restored)
- Secure Boot key re-enrollment
- OS reinstallation (if disk wiped)
- All user data will be lost (if disk wiped)

## Advanced Features

### ESP Configuration Extraction

Extract all ESP configurations to a JSON file for analysis:

```bash
sudo bash scripts/esp-config-extract.sh

# Output includes:
# - All config file locations
# - File sizes
# - Content previews
# - Boot variables
# - Editable status markers
```

Output file: `esp_configs_YYYYMMDD_HHMMSS.json`

### Nuclear Disk Wiping

For complete disk wiping with multiple methods:

```bash
sudo bash scripts/nuclear-wipe.sh

# Interactive mode (recommended)
# - ncurses interface
# - Visual disk selection
# - Progress monitoring

# Quick modes (automated)
# - Quick wipe: Zeros only
# - DoD Short: 3 passes
# - PRNG Stream: Cryptographically secure
```

### Variable Discovery and Analysis

Use Python tools for deep variable analysis:

```bash
# Discover all variables with categorization
python3 scripts/uefi_variable_discovery.py

# Analyze variable values and patterns
sudo python3 scripts/uefi_variable_analyzer.py
```

## Common Use Cases

### 1. Disable OEM Bloatware

**Problem:** Laptop came with MyASUS, Armoury Crate, or other OEM software that auto-installs.

**Solution:**
1. Boot into UUEFI
2. Press M for menu
3. Select option 4 (View Vendor Variables)
4. Note variables like `MyAsusAutoInstall`, `ArmouryCrateStaticField`
5. Select option 6 (Edit Variable)
6. Find the variable and set to 0 (Disable)
7. Reboot

**Result:** OEM software won't auto-install on Windows updates or OS reinstalls.

### 2. Speed Up Boot Times

**Problem:** BIOS animations slow down boot.

**Solution:**
1. Boot into UUEFI
2. Press M for menu
3. Select option 4 (View Vendor Variables)
4. Look for `AnimationSetupConfig` or similar
5. Select option 6 (Edit Variable)
6. Set to 0 (Disable)

**Result:** Faster boot times, especially on ASUS ROG laptops.

### 3. Security Audit

**Problem:** Want to verify no suspicious variables or firmware tampering.

**Solution:**
1. Boot into UUEFI
2. Wait for automatic scan to complete
3. Check for "Suspicious items detected" message
4. Press R to view security report
5. Review all HIGH severity items
6. Press M, then option 1 to see all variables
7. Export results for documentation

### 4. Malware/Rootkit Response

**Problem:** System compromised with persistent malware that survives OS reinstalls.

**Solution:**
1. Boot into UUEFI
2. Press M for menu
3. Select option 5 (Security Report)
4. Review all suspicious findings
5. If confirmed infection: Select N (Nuclear Wipe)
6. Follow all confirmation prompts carefully
7. After wipe: Boot to recovery USB
8. Run `nwipe` for complete disk wipe
9. Reinstall OS from trusted media
10. Re-enroll Secure Boot keys

### 5. System Decommissioning

**Problem:** Need to permanently erase all data before recycling/selling hardware.

**Solution:**
1. Boot into UUEFI
2. Press N for Nuclear Wipe
3. Complete Phase 1 & 2 (variable wipe)
4. Reboot to recovery environment
5. Run `sudo bash scripts/nuclear-wipe.sh`
6. Select option 4 (PRNG Stream) for highest security
7. Wait for completion (several hours)
8. System is now securely wiped

## Safety Features

UUEFI v3.0 includes multiple layers of safety:

### Protected Variables
These cannot be modified through UUEFI:
- `SecureBoot` - Secure Boot status
- `SetupMode` - Setup mode status  
- `PK` - Platform Key
- `KEK` - Key Exchange Key
- `db` - Signature Database
- `dbx` - Forbidden Signature Database
- `BootOrder` - Boot order (critical)
- `BootCurrent` - Current boot entry

### Confirmation Requirements
- Single confirmation: Viewing/scanning operations
- Double confirmation: Variable modifications
- Triple confirmation: Nuclear wipe operations

### Validation Checks
- Data size validation
- Attribute verification
- Category-based restrictions
- Type detection and validation

### Backup Recommendations
Before making changes:
1. Boot to OS and export variable list
2. Run `scripts/uefi_variable_discovery.py` to save state
3. Document current boot configuration
4. Take ESP backup: `sudo cp -r /boot/efi /backup/efi-backup`

## Troubleshooting

### UUEFI Won't Boot
```bash
# Remove UUEFI boot entry
sudo efibootmgr -b XXXX -B  # XXXX = UUEFI entry number

# Or boot to recovery and fix
sudo bash scripts/os-boot-clean.sh
```

### Changes Don't Take Effect
Some variables require specific conditions:
- System must be fully powered off (not sleep/hibernate)
- Some variables only apply on first boot after change
- Check if variable is marked as read-only
- May need to clear boot cache (power off + wait 30 seconds)

### Variable Modification Fails
```
✗ Failed to modify variable: Access Denied
  Variable may be read-only or protected
```

**Causes:**
- Variable has WRITE_PROTECT attribute
- Secure Boot is enforcing authentication
- BIOS has locked the variable
- Insufficient attributes set

**Solutions:**
- Check variable attributes in UUEFI listing
- Enter BIOS setup and check write-lock settings
- Some variables can only be changed in Setup Mode

### Nuclear Wipe Too Aggressive
If you accidentally wiped more than intended:
1. Don't panic - system is still bootable
2. Boot to BIOS/UEFI setup (DEL, F2, etc.)
3. Check boot devices - may need to manually add boot entry
4. For Secure Boot: Re-enroll keys using KeyEnrollEdk2.efi
5. For boot order: Use `efibootmgr` from live USB

## Technical Reference

### Variable Attributes

EFI variables have attributes that control their behavior:

```c
#define EFI_VARIABLE_NON_VOLATILE                          0x00000001
#define EFI_VARIABLE_BOOTSERVICE_ACCESS                    0x00000002
#define EFI_VARIABLE_RUNTIME_ACCESS                        0x00000004
#define EFI_VARIABLE_HARDWARE_ERROR_RECORD                 0x00000008
#define EFI_VARIABLE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS 0x00000020
#define EFI_VARIABLE_APPEND_WRITE                          0x00000040
```

Common combinations:
- `0x00000007` = NV + BS + RT (typical for boot/config variables)
- `0x00000027` = NV + BS + RT + AUTH (security variables)

### Variable Categories

UUEFI categorizes variables for easier management:

1. **Boot Configuration** (`VAR_CAT_BOOT`)
   - Boot####, BootOrder, BootCurrent, BootNext
   - Boot device configuration

2. **Security** (`VAR_CAT_SECURITY`)
   - PK, KEK, db, dbx
   - SecureBoot, SetupMode

3. **Hardware** (`VAR_CAT_HARDWARE`)
   - Hardware-specific settings
   - PCI, USB, SATA, NVMe configs

4. **Vendor** (`VAR_CAT_VENDOR`)
   - OEM-specific features
   - Vendor bloatware settings
   - Custom hardware features

5. **Unknown** (`VAR_CAT_UNKNOWN`)
   - Uncategorized variables
   - May need investigation

### Security Heuristics

UUEFI runs these checks on every variable:

1. **Large Variable Check**
   - Threshold: 32KB
   - Exceptions: db, dbx (can legitimately be large)
   - Severity: MEDIUM

2. **Boot Attribute Check**
   - Expected: NV + BS + RT
   - Detects: Tampering or malformed entries
   - Severity: MEDIUM

3. **Security Authentication Check**
   - Security vars should require authenticated writes
   - Detects: Bypass vulnerabilities
   - Severity: HIGH

4. **Suspicious Name Check**
   - Keywords: Debug, Test, Backdoor, Hidden
   - Detects: Development vars in production
   - Severity: MEDIUM

## Best Practices

### Before Using UUEFI

1. ✅ Backup your ESP: `sudo cp -r /boot/efi /backup/`
2. ✅ Export variable list: `python3 scripts/uefi_variable_discovery.py`
3. ✅ Test in VM first (if possible)
4. ✅ Read all warnings and confirmations carefully
5. ✅ Keep recovery USB handy

### When Editing Variables

1. ✅ Start with vendor-specific variables (safest)
2. ✅ Make one change at a time
3. ✅ Reboot and test after each change
4. ✅ Document what you changed and why
5. ✅ Have a plan to revert if needed

### After Using Nuclear Wipe

1. ✅ Document what was wiped
2. ✅ Reconfigure BIOS settings
3. ✅ Re-enroll Secure Boot keys
4. ✅ Verify boot order
5. ✅ Test system stability

## FAQ

**Q: Will UUEFI damage my hardware?**
A: No. UUEFI only modifies software (variables) stored in NVRAM. It cannot damage hardware. Worst case is you need to reset BIOS to defaults.

**Q: Can I brick my system?**
A: Extremely unlikely. UUEFI protects critical variables and preserves your current boot entry. If boot is broken, you can always boot from USB and fix with `efibootmgr`.

**Q: Do changes persist across OS reinstalls?**
A: Yes! That's the point. EFI variables are stored in NVRAM, separate from your OS disk.

**Q: Can I undo changes?**
A: Vendor variables can be set back to their original values. Boot entries can be recreated. Security variables should be changed through proper key enrollment tools.

**Q: Is this legal?**
A: Yes. You own your hardware. UUEFI is a tool for managing YOUR system configuration.

**Q: Will this void my warranty?**
A: Check your warranty terms. Most manufacturers allow BIOS configuration changes. This is similar to entering BIOS setup.

**Q: Can UUEFI detect all malware?**
A: No. UUEFI runs heuristics to detect suspicious patterns, but it's not a complete antivirus solution. Use it as part of a layered security approach.

**Q: How often should I run UUEFI?**
A: 
- Monthly: For security audits
- After firmware updates: To check for new variables
- When suspicious: If you suspect compromise
- Before decommissioning: For secure wipe

## Support and Contributing

### Getting Help

1. Check this documentation
2. Review `docs/UUEFI_ENHANCED.md`
3. Check `docs/UUEFI_INVESTIGATION.md` for troubleshooting
4. Open an issue on GitHub

### Contributing

Contributions welcome! Areas that need work:
- Additional variable descriptions
- More security heuristics
- Better numeric input handling
- Variable backup/restore
- JSON export from UUEFI itself

### Known Limitations

- Numeric input in menu requires typing (simplified in current version)
- Variable backup/restore requires OS tools
- ESP config editing read-only (safety feature)
- Some variables require Setup Mode to modify

## Credits

UUEFI v3.0 developed as part of PhoenixBoot/PhoenixGuard project.

Special thanks to:
- EDK2 project for UEFI development framework
- nwipe project for secure disk wiping
- All contributors to PhoenixBoot

## License

Part of PhoenixBoot project - Apache License 2.0

---

**Remember: With great power comes great responsibility. UUEFI gives you complete control over your system's firmware configuration. Use it wisely!** 🔥
