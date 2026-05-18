# PhoenixGuard TODO - Features Not Ready for Alpha

This document tracks features that exist in the codebase but are not yet ready for production use in the alpha release.

---

## 🚨 Critical: UUEFI Variable Editing Features

**Status**: ⚠️ EXPERIMENTAL - Code Complete but UNTESTED on real hardware

### Features Implemented

The UUEFI diagnostic tool (staging/src/UUEFI.c) includes sophisticated variable editing capabilities:

- **Variable Editing** (`EditVariable()` function)
  - Can modify scalar (1/2/4/8 byte) UEFI variables
  - Can delete vendor-specific variables
  - Supports enable/disable operations

- **Nuclear Wipe Menu** (`ShowNuclearWipeMenu()` function)
  - Option 1: Vendor Variable Wipe (removes non-critical vendor vars)
  - Option 2: Full NVRAM Reset (resets all non-security variables)
  - Option 3: Disk Wiping Information (informational only)
  - Option 4: Complete Nuclear Wipe workflow

### Safety Mechanisms

✅ These features include robust safety guards:

1. **GuardVariableModification()** - Prevents modifications when:
   - SecureBoot is enabled but no db keys exist (broken state)
   - System is in setup mode with SecureBoot enabled
   - Attempting to modify security variables (PK, KEK, db, dbx)

2. **UpdateVariableWithBackup()** - Ensures safe writes:
   - Creates backup before modification
   - Verifies write by reading back the variable
   - Rolls back to original value if verification fails
   - Returns EFI_COMPROMISED_DATA if verification fails

3. **Confirmation Prompts**:
   - Requires typing "WIPE" or "RESET" for destructive operations
   - Multiple confirmation steps for nuclear wipe
   - Clear warnings about data loss and risks

### Why Not Ready for Alpha

❌ **Hardware Testing Gap**: These features have NOT been tested on:
- Real UEFI firmware (only QEMU smoke tested)
- Various OEM implementations (ASUS, Dell, HP, Lenovo, etc.)
- Different SecureBoot configurations
- Edge cases like broken NVRAM or firmware bugs

❌ **Risk Assessment**: While safety guards are in place:
- A firmware bug could bypass our guards
- NVRAM corruption could occur during power loss
- Vendor-specific variables may have undocumented dependencies
- "Safe" variables might not be safe on all hardware

### Action Items Before Beta

- [ ] Test variable editing on 5+ different OEM systems
- [ ] Test in broken SecureBoot states (SB enabled, no keys)
- [ ] Verify rollback mechanism works on firmware errors
- [ ] Test nuclear wipe on sacrificial test hardware
- [ ] Document OEM-specific variable behaviors
- [ ] Create hardware compatibility matrix
- [ ] Add detection for known-bad firmware versions

### Recommended Alpha Approach

**Option 1**: Gate off write features entirely
```
- Disable Edit Variable menu option (option 6)
- Disable Nuclear Wipe menu (option 8)
- Keep read-only diagnostics (options 1-5, 7, 9)
```

**Option 2**: Add scary warnings
```
- Keep features enabled but add:
  "⚠️⚠️⚠️ EXPERIMENTAL - NOT TESTED ON REAL HARDWARE ⚠️⚠️⚠️"
  "USE AT YOUR OWN RISK - MAY BRICK YOUR SYSTEM"
  "THIS FEATURE IS FOR TESTING ONLY"
```

---

## 🧪 Testing Needed: Boot Media Scanning

**Status**: ⚠️ Needs False Positive Rate Validation

### Feature Description

UUEFI includes boot media anomaly detection (`AnalyzeCurrentBootMedia()`):
- Scans LBA0 for 0x55AA signature
- Validates GPT headers and protective MBR
- Checks for filesystem signatures on EFI partition
- Detects multiple active MBR partitions

### Concern

The heuristics may flag legitimate configurations as suspicious:
- Some firmware implementations have unusual partition layouts
- Live USB systems may have non-standard structures
- Recovery partitions might lack standard signatures

### Action Items

- [ ] Test on 20+ different boot media types
- [ ] Document known false positives
- [ ] Adjust heuristic sensitivity
- [ ] Add whitelist for known-good anomalies

---

## 📝 Documentation Needed

- [ ] Complete UUEFI user guide
- [ ] Hardware compatibility list
- [ ] Known issues and workarounds
- [ ] Safe usage guidelines
- [ ] Recovery procedures if variables are corrupted
