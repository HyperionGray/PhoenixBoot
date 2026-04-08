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

## The Six Escalation Levels

### Level 1: DETECT (Software-Based Scanning)
**What it does:** Comprehensive bootkit detection with zero system changes

**Risk:** ✅ None (read-only)  
**Time:** ~2 minutes  
**When to use:** Always start here

**Command:**
```bash
./pf.py secure-env
```

**Output:**
```
Risk Level: CLEAN | LOW | MEDIUM | HIGH | CRITICAL
```

---

### Level 2: SOFT (ESP Nuclear Boot ISO)
**What it does:** Deploys Nuclear Boot recovery environment to ESP

**Risk:** ⚠️ Low (modifies ESP, but reversible)  
**Time:** ~5-10 minutes  
**When to use:** MEDIUM threat level

**Command:**
```bash
./pf.py workflow-cd-prepare
sudo reboot
```

---

### Level 3: SECURE (Double-kexec Firmware Access)
**What it does:** Temporary firmware access using kexec

**Risk:** ⚠️ Medium (temporary security reduction)  
**Time:** ~10-15 minutes  
**When to use:** HIGH threat level

**Command:**
```bash
./pf.py kernel-kexec-check
./pf.py kernel-config-remediate
sudo bash out/remediation/kernel_remediation.sh
```

---

### Level 4: VM (Reboot to KVM Recovery Environment)
**What it does:** Reboots into isolated KVM recovery environment

**Risk:** ⚠️⚠️ Medium-High (system reboot required)  
**Time:** ~30-60 minutes  
**When to use:** HIGH threat level, need isolation

**Command:**
```bash
bash scripts/recovery/install_kvm_snapshot_jump.sh
bash scripts/recovery/reboot-to-vm.sh
```

---

### Level 5: XEN (Reboot to Xen dom0)
**What it does:** Ultimate isolation with Xen hypervisor

**Risk:** ⚠️⚠️⚠️ High (hypervisor reboot required)  
**Time:** ~1-2 hours  
**When to use:** CRITICAL threat level

---

### Level 6: HARDWARE (Direct SPI Flash Recovery)
**What it does:** Bypasses all software, directly programs firmware chip

**Risk:** ⚠️⚠️⚠️⚠️ Very High (can brick system)  
**Time:** ~2-4 hours  
**When to use:** All software methods failed

**Command:**
```bash
bash scripts/recovery/hardware-recovery.sh
```

⚠️ **WARNING:** This is the nuclear option. Only use if all other methods fail.

---

## Quick Start: Automatic Progressive Recovery

**The easy way - let PhoenixBoot decide:**

```bash
python3 scripts/recovery/phoenix_progressive.py
```

### Runtime Safety Improvement

`scripts/recovery/phoenix_progressive.py` now executes subprocesses with
argument-list commands (no `shell=True`). This reduces command-injection risk
and makes sudo usage explicit per recovery step.

This intelligent system:
1. Detects threat level
2. Recommends appropriate escalation
3. Asks for user confirmation
4. Executes recovery steps
5. Verifies success
6. Escalates if needed

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

## Nuclear Wipe Script (Emergency)

For severe infections:

```bash
sudo bash scripts/recovery/nuclear-wipe.sh
```

**Four Options:**
1. **Vendor variable wipe** - Remove bloatware (safe)
2. **Full NVRAM reset** - Factory defaults
3. **Disk wiping guide** - Instructions for nwipe
4. **Complete nuclear wipe** - NVRAM + disk (EXTREME)

⚠️ **WARNING:** Options 3 and 4 are PERMANENT!

---

## Decision Tree: Which Level Do I Need?

```
Start: Run Level 1 (DETECT)
  ↓
Risk Level?
  ↓
├─ CLEAN/LOW → ✅ Done (schedule next scan)
├─ MEDIUM → Level 2 (ESP cleanup)
├─ HIGH → Level 3 (kexec) or Level 4 (VM)
└─ CRITICAL → Level 5 (Xen) or Level 6 (Hardware)
```

---

## Success Criteria

After recovery, verify:

```bash
./pf.py secure-env
# Should show: Risk Level: CLEAN
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
