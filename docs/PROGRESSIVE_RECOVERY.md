# 🔥 PhoenixBoot: Progressive Recovery System (NuclearBoot)

## Overview

PhoenixBoot's **Progressive Recovery System** (also known as NuclearBoot) provides an intelligent, escalating approach to clearing bootkit infections and malicious EFI variables. Instead of immediately nuking your system, it tries the safest methods first and only escalates when necessary.

**Key Principle:** Start with the least invasive method, escalate only when needed.

---

## Why Progressive Escalation?

**The Problem with "Nuclear" Approaches:**
- Most recovery tools jump straight to the most destructive option
- Users lose data unnecessarily
- Overkill for 90% of infections

**PhoenixBoot's Solution:**
- Start with safe, non-destructive detection
- Escalate step-by-step based on threat level
- Users stay in control at every step
- Minimize data loss and downtime

**Result:** Most infections are cleared at Level 1-3 (software-based, non-destructive). Only severe infections require Level 4-6 (reboot/hardware).

---

## The First-Release Escalation Levels

### Level 1: FLASHROM (Direct Vendor BIOS Reflash)
**What it does:** Tries the obvious fix first: reflash a known-good vendor BIOS with `flashrom`.

**Risk:** ⚠️ Medium  
**Time:** ~5-15 minutes  
**When to use:** First recovery step once you have a trusted BIOS image

**Command:**
```bash
sudo FIRMWARE_PATH=/path/to/vendor-bios.bin ./pf.py firmware-recovery-restore
```

---

### Level 2: KEXEC (Double-Kexec Recovery)
**What it does:** If `flashrom` is blocked by kernel protections, switch to a permissive recovery posture, flash, then harden again with Secure Boot and custom keys.

**Risk:** ⚠️⚠️ Medium-High  
**Time:** ~10-20 minutes  
**When to use:** Direct flashing failed because the running kernel/lockdown path still owns boot

**Commands:**
```bash
./pf.py kernel-profile-permissive
sudo ./pf.py secureboot-enable-kexec
./pf.py kernel-profile-hardened
PROFILE=hardened ./pf.py kernel-profile-compare
```

> Even if a stubborn hardware foothold remains, custom Secure Boot keys plus a hardened kernel usually make the bootkit chain brittle enough that the system can remain usable and materially safer.

---

### Level 3: ESP-CD (Fake CD in the ESP)
**What it does:** Places the recovery ISO into the ESP so the next boot can jump into a minimal recovery OS without relying on your usual boot flow.

**Risk:** ⚠️⚠️ Medium-High  
**Time:** ~10-20 minutes  
**When to use:** You need a cleaner OS context for BIOS flashing

**Commands:**
```bash
./pf.py workflow-cd-prepare
sudo bash components/workflows/scripts/esp-packaging/deploy-esp-iso.sh --iso PhoenixGuard-Nuclear-Recovery.iso
sudo bash components/workflows/scripts/esp-packaging/boot-from-esp-iso.sh
```

The ESP should have enough free space for the recovery ISO before deploying it.

---

### Level 4: UUEFI (Targeted EFI Repair)
**What it does:** Installs UUEFI as the next boot so you can inspect and fix suspicious EFI variables against a trusted vendor baseline.

**Risk:** ⚠️⚠️ Medium-High  
**Time:** ~10 minutes  
**When to use:** The vendor BIOS is back, but EFI state still looks compromised

**Commands:**
```bash
./pf.py uuefi-install
./pf.py uuefi-apply
sudo reboot
```

---

### Level 5: UUEFI-NUKE (Aggressive EFI Reset)
**What it does:** Uses UUEFI to wipe and rebuild EFI state when targeted fixes are not enough.

**Risk:** ⚠️⚠️⚠️ High  
**Time:** ~15-30 minutes  
**When to use:** Targeted UUEFI repair failed and you are ready for destructive cleanup

This is where users should be warned clearly that the recovery path is getting risky.

**Commands:**
```bash
./pf.py uuefi-install
APP=UUEFI ./pf.py uuefi-apply
sudo reboot
# In UUEFI: Nuclear Wipe -> Full NVRAM reset, then rebuild trusted boot entries
./pf.py uuefi-report
```

---

### Level 6: CMOS (Manual Motherboard Reset)
**What it does:** Gives the user the old-school board-level reset instructions many people never try.

**Risk:** ⚠️ Medium  
**Time:** A few hours  
**When to use:** Software-driven recovery paths are exhausted

Try:
- Clear-CMOS / clear-BIOS jumpers or reset buttons
- Remove AC power and the main battery
- Remove the CMOS battery
- Wait at least a couple of hours before reassembly

---

### Level 7: CH341A (External Programmer)
**What it does:** Moves to an external programmer when the platform is locked in SPI/DXE protections or otherwise refuses software recovery.

**Risk:** ⚠️⚠️⚠️⚠️ Very High  
**Time:** ~1-4 hours  
**When to use:** All softer options failed

**Commands:**
```bash
flashrom -p ch341a_spi -r current_firmware_backup.bin
flashrom -p ch341a_spi -w /path/to/vendor-bios.bin -V
flashrom -p ch341a_spi -v /path/to/vendor-bios.bin
```

Need help or a programmer? Contact **bootkit@hyperiongray.com**. Alex (`_hyp3ri0n` / `P4X`) will try to help, though OSS support may take a bit.

---

## Quick Start: Guided Progressive Recovery

**The easy way - let PhoenixBoot decide:**

```bash
python3 components/workflows/scripts/recovery/autonuke.py
```

This intelligent system:
1. Starts with `flashrom`
2. Escalates to the double-kexec path when firmware protections get in the way
3. Offers the ESP fake-CD recovery environment
4. Walks you into UUEFI targeted and destructive EFI repair
5. Ends with manual reset and CH341A guidance if the platform is still locked down

---

## Manual Recovery with UUEFI

For users who prefer manual inspection:

```bash
# Install UUEFI diagnostic tool
./pf.py uuefi-install

# Set as next boot
./pf.py uuefi-apply

# Reboot
sudo reboot
```

**UUEFI provides:**
- View ALL EFI variables
- Edit tweakable variables
- Security analysis
- Nuclear wipe options

See [UUEFI v3 Guide](UUEFI_V3_GUIDE.md) for details.

---

## Decision Tree: Which Level Do I Need?

```
Start: Run Level 1 (FLASHROM)
  ↓
Did the vendor BIOS reflash work?
  ↓
├─ Yes → ✅ Re-enable hardening and stop
└─ No
   ├─ Kernel protections blocking flashrom? → Level 2 (KEXEC)
   ├─ Need cleaner recovery OS? → Level 3 (ESP-CD)
   ├─ EFI variables still suspect? → Level 4 (UUEFI)
   ├─ Need destructive EFI cleanup? → Level 5 (UUEFI-NUKE)
   ├─ Firmware still stuck? → Level 6 (CMOS)
   └─ Platform still locked? → Level 7 (CH341A)
```

---

## Success Criteria

After recovery, verify:

```bash
./pf.py secureboot-check
PROFILE=hardened ./pf.py kernel-profile-compare
```

---

## Technical Reference

For technical details, command syntax, and advanced usage:
- **[Technical Reference](PROGRESSIVE_RECOVERY_TECHNICAL.md)** - Detailed commands and planfile format
- **[Complete Workflow](../BOOTKIT_DEFENSE_WORKFLOW.md)** - All three stages
- **[UUEFI Guide](UUEFI_V3_GUIDE.md)** - Interactive variable management

---

## Community Support

- **GitHub Issues**: https://github.com/P4X-ng/PhoenixBoot/issues
- **Documentation**: `docs/` directory

---

**Made with 🔥 by PhoenixBoot - Progressive recovery from safest to most extreme**
