# Progressive Recovery

This document describes the PhoenixGuard progressive recovery ladder and how to operate it safely in production.

Principles
- Safe-by-default: No host modifications unless you opt in (PG_HOST_OK=1).
- No demo contamination: Only production assets from staging/ and scripts/ are used.
- Auditability: Every run can produce a JSON planfile under plans/.
- Clear safety gates: Destructive steps require explicit confirmation.

Commands
- Interactive (safe defaults):
  ./pf.py nuke-progressive

- Dry run (planfile only, no changes):
  ./pf.py nuke-progressive-dry-run
  # Or directly:
  python3 scripts/recovery/phoenix_progressive.py --dry-run --yes

- Individual levels:
  - Level 1 — Detect (read-only scan)
    ./pf.py nuke-level1-scan
  - Level 2 — ESP deploy (requires prepared ISO)
    ISO_PATH=/path/to/PhoenixGuard-Nuclear-Recovery.iso ./pf.py nuke-level2-esp
  - Level 3 — Secure firmware access (double-kexec)
    ./pf.py nuke-level3-secure
  - Level 4 — KVM Snapshot Jump reboot path
    ./pf.py nuke-level4-kvm
  - Level 6 — Hardware recovery (danger)
    ./pf.py nuke-level6-hw

Safety gates
- Level 1: Non-destructive scan.
- Level 2: Can modify host ESP and GRUB; requires explicit confirmation and a provided ISO.
- Level 3: Requires root; temporarily disables kernel lockdown and re-locks automatically.
- Level 4: Reboot paths; ensure KVM configurations are prepared.
- Level 6: Dangerous; type-to-confirm inside the tool and ensure you have a programmer backup.

Planfile output
- Written to plans/phoenix_progressive_<timestamp>.json, includes:
  - run metadata: run_id, created_utc, dry_run, auto_approve, cwd
  - levels attempted with per-step command arrays and statuses
  - outputs: logs_dir and plan_path
  - errors: top-level unexpected errors

Baseline and scanning
- The scanner script (scripts/scan-bootkits.sh) will:
  - Use /home/punk/.venv/bin/python3 if present
  - Create baseline at out/baseline/firmware_baseline.json (unless overridden via BASELINE_JSON)
  - Save scan results to out/logs/bootkit_scan_results.json (unless overridden via SCAN_OUT)

Rollback guidance
- Level 2 (host deploy): Remove /etc/grub.d/42_phoenixguard_recovery and rerun update-grub.
- Level 3: A second kexec returns to lockdown=integrity; reboot restores kernel defaults.
- Level 4: Reboot back to metal and normal boot order; remove KVM assets if desired.
- Level 6: Reflash prior backup firmware image.

Troubleshooting
- OVMF not found: run ./pf.py build-setup then ./pf.py build-package-esp.
- ESP verification fails: inspect out/logs/esp-normalize-secure.log and ensure keys exist.
- Baseline analyzer missing: add dev/tools/analyze_firmware_baseline.py or specify BASELINE_JSON to an existing baseline.
