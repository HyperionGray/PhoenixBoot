# UUEFI Secure Boot Variable Guarding

## Overview

UUEFI v3.2.0 introduces comprehensive secure boot variable guarding and validation to prevent hardware lockouts and system bricking. This feature addresses the common issue where BIOS/UEFI firmware appears to have secure boot enabled but is not properly configured, potentially leading to boot failures or hardware locks.

## Problem Statement

Sometimes UEFI firmware doesn't properly enable secure boot, or it appears enabled but isn't functioning correctly. This can happen when:

1. **SecureBoot variable is enabled but no keys exist in db** - The most dangerous state
2. **Keys were manually deleted while SecureBoot remained enabled**
3. **Firmware bug leaves system in inconsistent state**
4. **Factory reset didn't properly disable SecureBoot**
5. **NVRAM corruption affecting security variables**

Without proper validation, modifying other UEFI variables in these states can:
- Cause boot failures
- Lock the hardware until reset
- Require recovery procedures
- In extreme cases, brick the system

## Solution: Variable Guarding

UUEFI v3.2.0 implements a multi-layer protection system that:

### 1. Validates Secure Boot Configuration

**Function**: `CheckSecureBootConfiguration()`

Performs comprehensive validation:
- Checks if SecureBoot variable exists and is readable
- Validates if SetupMode variable indicates proper state
- Verifies at least one key exists in db database
- Detects broken configurations (SecureBoot on, no db keys)

Returns:
- `IsProperlyConfigured`: TRUE if system is in safe state
- `DiagnosticMessage`: Human-readable status explanation

### 2. Validates db Signature Database

**Function**: `ValidateDbKeys()`

Checks the db (signature database) UEFI variable:
- Confirms db variable exists
- Verifies db has data (at least one key)
- Returns TRUE if valid keys are present

The db database contains authorized signatures for bootloaders and kernels. Without keys in db, secure boot cannot function.

### 3. Guards Variable Modifications

**Function**: `GuardVariableModification()`

Before allowing ANY variable modification, checks:

**Always Protected**:
- Security variables: PK, KEK, db, dbx, SecureBoot, SetupMode
- Reason: These control secure boot and should only be modified through proper enrollment procedures

**Protected When System is Unsafe**:
- Boot variables: BootOrder, BootCurrent, etc. (when SecureBoot enabled in setup mode)
- Reason: Modifying boot configuration in unstable state can prevent booting

**Protected in Broken State**:
- ALL variables blocked if SecureBoot is enabled but db is empty
- Reason: System is in dangerous state; any modification could brick hardware

**Allowed When Safe**:
- Vendor-specific variables (when system is properly configured)
- Reason: Safe to disable vendor features if secure boot is stable

## Usage

### Interactive Menu Option 9: Validate Secure Boot Configuration

The new menu option provides a comprehensive report:

```
╔════════════════════════════════════════════╗
║    SECURE BOOT VALIDATION REPORT          ║
╚════════════════════════════════════════════╝

Current Status:
───────────────
SecureBoot Variable: Enabled
SetupMode Variable: No (User)
db Keys Present: Yes

Overall Assessment:
───────────────────
✓ Secure Boot properly configured and active
```

### Automatic Protection

Variable modification attempts are automatically guarded:

**Example 1: Critical Warning**
```
⚠ BLOCKED: System in unsafe state (SecureBoot on but no keys). 
Fix secure boot configuration first.
```

**Example 2: Security Variable Protection**
```
⚠ BLOCKED: Security variables are protected from modification
```

**Example 3: Unstable System**
```
⚠ BLOCKED: Cannot modify boot variables in setup mode with SecureBoot enabled
```

### Enhanced Security Display

On startup, UUEFI now shows:

```
=== Security Status ===
Secure Boot: Enabled
Setup Mode: No
db Keys Present: Yes
Configuration: ✓ Secure Boot properly configured and active
```

If a critical issue is detected:

```
⚠⚠⚠ CRITICAL WARNING ⚠⚠⚠
SecureBoot appears enabled but no keys are in the db database!
This may indicate:
  - Firmware bug or incomplete secure boot implementation
  - Keys were deleted but SecureBoot wasn't properly disabled
  - System is in an inconsistent state

Recommended actions:
  1. Enter firmware setup and verify secure boot settings
  2. Either enroll keys or properly disable secure boot
  3. Do NOT modify other UEFI variables until this is resolved
```

## Secure Boot States

### State 1: Properly Configured ✓

```
SecureBoot: Enabled
SetupMode: No (User Mode)
db Keys: Present
```

**Status**: ✓ Safe to operate
**Variable Modifications**: Vendor variables allowed
**Description**: Ideal state - secure boot is active and functioning

### State 2: Disabled with Keys

```
SecureBoot: Disabled
SetupMode: No (User Mode)
db Keys: Present
```

**Status**: ℹ Safe to operate
**Variable Modifications**: Vendor variables allowed
**Description**: Valid configuration - secure boot disabled intentionally

### State 3: Setup Mode (Normal)

```
SecureBoot: Enabled
SetupMode: Yes (Setup Mode)
db Keys: Present or Not Present
```

**Status**: ℹ Intermediate state
**Variable Modifications**: Boot variables blocked, vendor variables allowed
**Description**: Normal state during key enrollment - waiting for PK to be set

### State 4: Broken Configuration ⚠⚠⚠

```
SecureBoot: Enabled
SetupMode: No (User Mode)
db Keys: NOT Present
```

**Status**: ⚠⚠⚠ CRITICAL - System unsafe
**Variable Modifications**: ALL BLOCKED
**Description**: Dangerous state - SecureBoot on but no keys. Must be fixed immediately.

### State 5: Not Configured

```
SecureBoot: Disabled
SetupMode: No (User Mode)
db Keys: NOT Present
```

**Status**: ℹ Safe to operate
**Variable Modifications**: Vendor variables allowed
**Description**: Secure boot not set up - maximum compatibility mode

## Recovery from Broken State

If UUEFI detects State 4 (Broken Configuration):

### Step 1: Enter Firmware Setup
- Reboot system
- Press DEL, F2, or firmware setup key at boot
- Navigate to Security or Boot settings

### Step 2: Fix Secure Boot

**Option A**: Disable Secure Boot (Quick)
1. Find "Secure Boot" option
2. Set to "Disabled"
3. Save and exit
4. Reboot and run UUEFI to verify

**Option B**: Enroll Keys (Secure)
1. Look for "Restore Factory Keys" or "Enroll Default Keys"
2. Execute the restoration
3. Save and exit
4. Reboot and run UUEFI to verify

**Option C**: Complete Reset (Nuclear)
1. Use UUEFI Nuclear Wipe Menu option 2 (Full NVRAM Reset)
2. This preserves security keys IF they exist elsewhere
3. Reboot to firmware setup
4. Reconfigure secure boot from scratch

### Step 3: Verify Fix

Run UUEFI again and check:
1. Menu option 9: "Validate Secure Boot Configuration"
2. Verify no critical warnings
3. Confirm variables are editable again

## API Reference

### ValidateDbKeys()

```c
EFI_STATUS ValidateDbKeys(
  OUT BOOLEAN *HasValidKey
)
```

**Parameters**:
- `HasValidKey`: Returns TRUE if db has at least one key

**Returns**: EFI_SUCCESS (check HasValidKey for result)

**Usage**:
```c
BOOLEAN HasDbKey = FALSE;
ValidateDbKeys(&HasDbKey);
if (!HasDbKey) {
  Print(L"No keys in db database\n");
}
```

### CheckSecureBootConfiguration()

```c
EFI_STATUS CheckSecureBootConfiguration(
  OUT BOOLEAN *IsProperlyConfigured,
  OUT CHAR16 *DiagnosticMessage
)
```

**Parameters**:
- `IsProperlyConfigured`: TRUE if system is in safe state
- `DiagnosticMessage`: Human-readable status (buffer size 256)

**Returns**: EFI_SUCCESS

**Usage**:
```c
BOOLEAN IsConfigured = FALSE;
CHAR16 Message[256];
CheckSecureBootConfiguration(&IsConfigured, Message);
Print(L"Status: %s\n", Message);
```

### GuardVariableModification()

```c
EFI_STATUS GuardVariableModification(
  IN VARIABLE_INFO *VarInfo,
  OUT BOOLEAN *AllowModification,
  OUT CHAR16 *WarningMessage
)
```

**Parameters**:
- `VarInfo`: Variable to check
- `AllowModification`: TRUE if safe to modify
- `WarningMessage`: Explanation if blocked (buffer size 256)

**Returns**: EFI_SUCCESS

**Usage**:
```c
BOOLEAN AllowMod = FALSE;
CHAR16 Warning[256];
GuardVariableModification(&myVar, &AllowMod, Warning);
if (!AllowMod) {
  Print(L"Blocked: %s\n", Warning);
  return EFI_ACCESS_DENIED;
}
```

## Implementation Details

### Protection Hierarchy

1. **Level 1**: Always Protected
   - Security variables (PK, KEK, db, dbx, SecureBoot, SetupMode)
   - Cannot be modified through UUEFI - use KeyEnrollEdk2.efi

2. **Level 2**: Conditionally Protected
   - Boot variables (BootOrder, BootCurrent, BootNext, Boot####)
   - Protected when: System in setup mode with SecureBoot enabled

3. **Level 3**: System State Protected
   - ALL variables (including vendor)
   - Protected when: SecureBoot enabled but db empty

4. **Level 4**: Conditionally Allowed
   - Vendor variables marked as editable
   - Allowed when: System properly configured OR SecureBoot disabled

### Detection Logic

```c
// Detect broken state
if (SecureBoot && !HasDbKey) {
  // CRITICAL: Block everything
  return BLOCKED;
}

// Check variable category
if (Category == SECURITY) {
  // Always protected
  return BLOCKED;
}

if (Category == BOOT && SecureBoot && SetupMode) {
  // Don't modify boot vars in unstable state
  return BLOCKED;
}

if (IsEditable && IsConfigured) {
  // Safe to modify vendor vars
  return ALLOWED;
}

// Default: block
return BLOCKED;
```

## Safety Philosophy

UUEFI follows a **"fail-safe, prevent bricking"** approach:

1. **Detect Before Act**: Always validate state before modifications
2. **Block Dangerous Operations**: Better to block than brick
3. **Clear Communication**: Explain why something is blocked
4. **Provide Solutions**: Guide user to fix issues
5. **Preserve Critical Data**: Never touch security variables
6. **Recover Gracefully**: Support recovery from unsafe states

## Testing Scenarios

### Test 1: Normal Operation
```
Setup: SecureBoot enabled, keys present, user mode
Expected: Vendor variables editable, security/boot protected
Result: ✓ Pass
```

### Test 2: Broken State Detection
```
Setup: SecureBoot enabled, NO keys in db
Expected: ALL modifications blocked, critical warning shown
Result: ✓ Pass
```

### Test 3: Setup Mode Protection
```
Setup: SecureBoot enabled, setup mode active
Expected: Boot variables blocked, vendor variables allowed
Result: ✓ Pass
```

### Test 4: Disabled Secure Boot
```
Setup: SecureBoot disabled (keys may or may not exist)
Expected: Vendor variables allowed, security variables protected
Result: ✓ Pass
```

### Test 5: Recovery Workflow
```
Setup: Start with broken state (SecureBoot on, no keys)
Actions: Enter firmware, disable SecureBoot, save, reboot
Expected: UUEFI detects fix, allows modifications again
Result: ✓ Pass
```

## Known Limitations

1. **Cannot Fix Broken State**: UUEFI can detect but not automatically fix broken configurations
2. **Firmware Dependent**: Detection relies on firmware properly reporting variables
3. **No Key Parsing**: Validates db exists and has data, but doesn't parse signature lists
4. **No TPM Integration**: Doesn't check TPM state or measured boot
5. **User Must Act**: Requires user to enter firmware setup for fixes

## Future Enhancements

Potential improvements for v4.0:

1. **Automatic Key Enrollment**: Integrate KeyEnrollEdk2 functionality
2. **MOK Validation**: Check Machine Owner Keys for module signing
3. **TPM Integration**: Validate measured boot chain
4. **Key Parsing**: Parse and display actual keys in db
5. **Automated Recovery**: Attempt to fix broken states automatically
6. **Hardware Lock Detection**: Check for firmware write protection
7. **Cloud Attestation**: Report secure boot state to PhoenixGuard cloud

## References

- [UEFI Specification - Variable Services](https://uefi.org/specs/UEFI/2.10/08_Services_Runtime_Services.html#variable-services)
- [UEFI Secure Boot Specification](https://uefi.org/specs/UEFI/2.10/32_Secure_Boot.html)
- [PhoenixBoot Architecture](ARCHITECTURE.md)
- [UUEFI v3 Features](UUEFI_V3_FEATURES.md)

## Support

For issues with secure boot guarding:
- GitHub Issues: https://github.com/P4X-ng/PhoenixBoot/issues
- Documentation: See `docs/` directory
- Example broken state reports welcome for improving detection

---

**⚠ REMEMBER**: If UUEFI blocks a modification, there's a good reason. Don't try to bypass the protection - fix the underlying issue first!

**Made with 🔥 by PhoenixBoot - Preventing hardware bricks since 2025**
