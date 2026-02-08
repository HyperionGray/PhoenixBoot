# 🔥 PhoenixBoot: Quick Reference Card

**Stop Bootkits in Three Stages**

---

## Stage 1: Create SecureBoot Bootable Media 🔐

**One command:**
```bash
./create-secureboot-bootable-media.sh --iso /path/to/distro.iso --usb-device /dev/sdX
# (or: ./pf.py secureboot-create iso_path=/path/to/distro.iso usb_device=/dev/sdX  # alias secureboot-create-usb)
```

**First boot:**
- Enable SecureBoot in BIOS
- Boot from media
- Install your OS normally

---

## Stage 2: Install OS with SecureBoot 💿

**After install, sign kernel modules:**
```bash
./sign-kernel-modules.sh
```

**Verify clean installation:**
```bash
./pf.py secure-env
```

---

## Stage 3: Clear Malicious EFI Vars 🔥

**Quick security check:**
```bash
./pf.py secure-env
```

**Automatic recovery (recommended):**
```bash
python3 scripts/recovery/phoenix_progressive.py
```

**Manual inspection:**
```bash
./pf.py uuefi-apply && sudo reboot
```

**Emergency nuclear wipe:**
```bash
sudo bash scripts/recovery/nuclear-wipe.sh
```

---

## Recovery Levels (Progressive Escalation)

| Level | Risk | Time | Use When |
|-------|------|------|----------|
| 1: DETECT | ✅ None | 2 min | Always start here |
| 2: SOFT | ⚠️ Low | 10 min | MEDIUM threat |
| 3: SECURE | ⚠️ Medium | 15 min | HIGH threat |
| 4: VM | ⚠️⚠️ High | 60 min | Need isolation |
| 5: XEN | ⚠️⚠️⚠️ Very High | 2 hrs | CRITICAL threat |
| 6: HARDWARE | ⚠️⚠️⚠️⚠️ Extreme | 4 hrs | All else failed |

---

## Common Tasks

**List all tasks:**
```bash
./pf.py list
```

**Interactive wizard:**
```bash
./phoenixboot-wizard.sh
```

**Interactive TUI:**
```bash
./phoenixboot-tui.sh
```

**Generate SecureBoot keys:**
```bash
./pf.py secure-keygen
```

**Enroll MOK:**
```bash
./pf.py os-mok-enroll
```

**Sign kernel modules:**
```bash
MODULE_PATH=/path/to/module.ko ./pf.py os-kmod-sign
```

**QEMU tests:**
```bash
./pf.py test-qemu
./pf.py test-qemu-secure-positive
```

---

## Decision Tree

```
1. Create bootable media (Stage 1)
     ↓
2. Install OS with SecureBoot (Stage 2)
     ↓
3. Sign kernel modules
     ↓
4. Run security check: ./pf.py secure-env
     ↓
     ├─ CLEAN → ✅ Done! (schedule weekly scans)
     ├─ MEDIUM → Run Level 2 recovery
     ├─ HIGH → Run Level 3-4 recovery
     └─ CRITICAL → Run Level 5-6 recovery
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Security Violation" | Disable SecureBoot OR enroll keys |
| Module won't load | Sign it: `./sign-kernel-modules.sh` |
| SecureBoot won't enable | Check BIOS, verify key enrollment |
| Bootkit detected | Run progressive recovery |
| System bricked | Hardware recovery with CH341A |

---

## Important Files

| File/Dir | Purpose |
|----------|---------|
| `keys/` | Your SecureBoot keys (KEEP SAFE!) |
| `out/esp/` | Bootable images |
| `out/keys/mok/` | MOK certificates |
| `out/qemu/` | Test logs |
| `staging/boot/` | UEFI applications |

---

## Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install openssl dosfstools sbsigntool efitools \
  efibootmgr mokutil qemu-system-x86 ovmf python3
```

**Fedora/RHEL:**
```bash
sudo dnf install openssl dosfstools sbsigntools efitools \
  efibootmgr mokutil qemu-system-x86 edk2-ovmf python3
```

---

## Safety Tips

1. ✅ Always start with Level 1 (DETECT)
2. ✅ Escalate gradually, don't jump to hardware
3. ✅ Keep backups of firmware and keys
4. ✅ Use CD/DVD for boot media (immutable!)
5. ✅ Run weekly security scans
6. ⚠️ Never run nuclear wipe without backups

---

## Resources

- **Full Guide:** [BOOTKIT_DEFENSE_WORKFLOW.md](BOOTKIT_DEFENSE_WORKFLOW.md)
- **Progressive Recovery:** [docs/PROGRESSIVE_RECOVERY.md](docs/PROGRESSIVE_RECOVERY.md)
- **UUEFI Guide:** [docs/UUEFI_V3_GUIDE.md](docs/UUEFI_V3_GUIDE.md)
- **Getting Started:** [GETTING_STARTED.md](GETTING_STARTED.md)
- **GitHub Issues:** https://github.com/P4X-ng/PhoenixBoot/issues

---

## Success Criteria

After completing all stages, you should have:
- ✅ Custom SecureBoot keys enrolled
- ✅ Clean OS with verified boot chain
- ✅ Signed kernel modules
- ✅ No suspicious EFI variables
- ✅ Security scan showing CLEAN

**Result:** 99% of bootkits neutralized! 🔥

---

**Made with 🔥 by PhoenixBoot - Stop bootkits, period.**
