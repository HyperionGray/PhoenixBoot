#!/usr/bin/env python3
"""
PhoenixGuard Progressive Escalation Recovery System.

Implements a safest-to-most-invasive recovery ladder:
1. DETECT   - software bootkit detection
2. SOFT     - ESP recovery ISO deployment
3. SECURE   - temporary secure firmware access
4. VM       - reboot to KVM recovery
5. XEN      - reboot to Xen isolation path
6. HARDWARE - direct SPI flash recovery
"""

import argparse
import json
import os
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple


class PhoenixProgressiveRecovery:
    def __init__(
        self,
        dry_run: bool = False,
        auto_approve: bool = False,
        only_level: Optional[int] = None,
        plan_path: Optional[str] = None,
        iso_path: Optional[str] = None,
    ):
        self.dry_run = dry_run
        self.auto_approve = auto_approve
        self.only_level = only_level
        self.project_root = self._find_project_root()
        self.risk_level = "UNKNOWN"
        self.results: Dict[str, Any] = {}
        self.plan_path = Path(plan_path) if plan_path else self._default_plan_path()
        self.iso_path = Path(iso_path) if iso_path else self.project_root / "PhoenixGuard-Nuclear-Recovery.iso"
        self.plan: Dict[str, Any] = {
            "tool": {"name": "phoenix_progressive", "version": "2.0.0"},
            "run": {
                "run_id": f"pg-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}",
                "created_utc": self._utc_now(),
                "dry_run": self.dry_run,
                "auto_approve": self.auto_approve,
                "cwd": str(self.project_root),
                "only_level": self.only_level,
            },
            "levels": [],
            "outputs": {"logs_dir": "out/logs", "plan_path": ""},
            "errors": [],
        }

    def _find_project_root(self) -> Path:
        cwd = Path(__file__).resolve().parent
        for candidate in [cwd, *cwd.parents]:
            if (candidate / ".git").exists():
                return candidate
        return Path.cwd()

    def _default_plan_path(self) -> Path:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
        return self.project_root / "plans" / f"phoenix_progressive_{stamp}.json"

    @staticmethod
    def _utc_now() -> str:
        return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    def _start_level(self, level_num: int, name: str, description: str) -> Dict[str, Any]:
        record = {
            "level": level_num,
            "name": name,
            "description": description,
            "started_utc": self._utc_now(),
            "ended_utc": None,
            "ok": False,
            "steps": [],
            "error": None,
        }
        self.plan["levels"].append(record)
        return record

    def _end_level(self, record: Dict[str, Any], ok: bool, error: Optional[str] = None) -> None:
        record["ok"] = ok
        record["error"] = error
        record["ended_utc"] = self._utc_now()

    def _record_step(
        self,
        level_record: Dict[str, Any],
        description: str,
        command: Sequence[str],
        status: str,
        returncode: int,
        stdout: str = "",
        stderr: str = "",
    ) -> None:
        level_record["steps"].append(
            {
                "description": description,
                "command": list(command),
                "command_str": " ".join(shlex.quote(part) for part in command),
                "status": status,
                "returncode": returncode,
                "stdout": stdout,
                "stderr": stderr,
                "timestamp_utc": self._utc_now(),
            }
        )

    def print_banner(self) -> None:
        print("☠ PHOENIXGUARD - Progressive Bootkit Defense & Recovery")
        print("=" * 56)
        print("☠ Intelligent escalation from safest to most extreme recovery methods")
        print()

    def run_command(
        self,
        cmd: Sequence[str],
        level_record: Dict[str, Any],
        description: str = "",
        check: bool = True,
        capture_output: bool = True,
        allow_in_dry_run: bool = False,
        input_text: Optional[str] = None,
    ) -> Tuple[str, str, int]:
        if description:
            print(f"☠ {description}")

        if self.dry_run and not allow_in_dry_run:
            print(f"   DRY-RUN: {' '.join(shlex.quote(part) for part in cmd)}")
            self._record_step(
                level_record,
                description or "dry-run command",
                cmd,
                "dry-run",
                0,
                "",
                "",
            )
            return "", "", 0

        try:
            result = subprocess.run(
                list(cmd),
                cwd=self.project_root,
                capture_output=capture_output,
                text=True,
                check=check,
                input=input_text,
            )
            stdout = result.stdout or ""
            stderr = result.stderr or ""
            self._record_step(
                level_record,
                description or "command",
                cmd,
                "ok",
                result.returncode,
                stdout,
                stderr,
            )
            return stdout, stderr, result.returncode
        except subprocess.CalledProcessError as exc:
            stdout = exc.stdout or ""
            stderr = exc.stderr or str(exc)
            self._record_step(
                level_record,
                description or "command",
                cmd,
                "error",
                exc.returncode,
                stdout,
                stderr,
            )
            if check:
                print(f"☠ Command failed: {' '.join(cmd)}")
                print(f"   Error: {stderr.strip() or exc}")
            return stdout, stderr, exc.returncode
        except Exception as exc:
            self._record_step(
                level_record,
                description or "command",
                cmd,
                "exception",
                1,
                "",
                str(exc),
            )
            print(f"☠ Unexpected error running: {' '.join(cmd)}")
            print(f"   Error: {exc}")
            return "", str(exc), 1

    def _load_scan_results(self) -> None:
        scan_paths = [
            self.project_root / "out/logs/bootkit_scan_results.json",
            self.project_root / "bootkit_scan_results.json",
        ]
        for path in scan_paths:
            if path.exists():
                try:
                    with path.open("r", encoding="utf-8") as handle:
                        scan_results = json.load(handle)
                    self.risk_level = scan_results.get("risk_level", "UNKNOWN")
                    self.results["level_1_scan"] = scan_results
                    return
                except Exception:
                    self.risk_level = "UNKNOWN"
                    return

    def level_1_detect(self, level_record: Dict[str, Any]) -> bool:
        print("☠ LEVEL 1: DETECT - Software-based bootkit scanning")
        print("=" * 50)
        print("This performs comprehensive bootkit detection with zero system changes.")
        print("☠ Safe: No modifications to system")
        print("☠ Fast: Usually completes in under 2 minutes")
        print("☠ Comprehensive: Scans firmware, NVRAM, bootloaders")
        print()

        if not self.confirm_escalation("scan for bootkit infections"):
            return False

        _, _, returncode = self.run_command(
            ["bash", "scripts/validation/scan-bootkits.sh"],
            level_record=level_record,
            description="Running bootkit detection scan",
        )

        if returncode != 0 and not self.dry_run:
            return False

        self._load_scan_results()
        print()
        print(f"☠ Scan Results: Risk Level = {self.risk_level}")

        if self.dry_run:
            print("☠ Dry-run mode: continuing to next level for full plan coverage.")
            return False

        if self.risk_level in ["CLEAN", "LOW"]:
            print("☠ System appears clean! No further escalation needed.")
            print("☠ Recommendation: Continue normal operations with periodic scans.")
            return True
        if self.risk_level in ["MEDIUM", "HIGH"]:
            print("☠ Potential threats detected. Escalation to Level 2 recommended.")
        elif self.risk_level == "CRITICAL":
            print("☠ CRITICAL threats detected! Immediate escalation recommended.")

        print()
        return False

    def level_2_soft(self, level_record: Dict[str, Any]) -> bool:
        print("☠ LEVEL 2: SOFT - ESP Nuclear Boot ISO deployment")
        print("=" * 50)
        print("This deploys recovery tools directly to your ESP partition.")
        print("☠ Safe: No system reboots required")
        print("☠ Fast: Software-only deployment")
        print("☠ Persistent: Creates recovery option in boot menu")
        print("☠ Modifies: Adds files to ESP and GRUB configuration")
        print()

        if not self.confirm_escalation("deploy Nuclear Boot recovery ISO to ESP"):
            return False

        if not self.iso_path.exists() and not self.dry_run:
            print(f"☠ Recovery ISO not found: {self.iso_path}")
            print("   Provide one via --iso-path or ISO_PATH environment variable.")
            print("   Level 2 cannot proceed without a prepared recovery ISO.")
            return False

        _, _, returncode = self.run_command(
            ["sudo", "bash", "scripts/esp-packaging/deploy-esp-iso.sh", "--iso", str(self.iso_path)],
            level_record=level_record,
            description="Deploying recovery ISO to ESP",
            capture_output=False,
        )
        if returncode != 0:
            print("☠ Failed to deploy recovery ISO")
            return False

        print()
        print("☠ Nuclear Boot recovery deployed successfully!")
        print("☠ Next steps:")
        print("  1. Reboot and select 'PhoenixGuard Nuclear Boot Recovery (Virtual CD)' from GRUB menu")
        print("  2. Or run 'scripts/esp-packaging/boot-from-esp-iso.sh' to access tools immediately")
        print()

        if self.dry_run:
            return False

        choice = "n"
        if self.auto_approve:
            print("☠ Auto-approve enabled: skipping immediate boot prompt.")
        else:
            choice = input("☠ Boot recovery environment now? [y/N]: ").strip().lower()
        if choice == "y":
            self.run_command(
                ["bash", "scripts/esp-packaging/boot-from-esp-iso.sh"],
                level_record=level_record,
                description="Booting recovery environment from ESP ISO",
                capture_output=False,
            )

        return True

    def level_3_secure(self, level_record: Dict[str, Any]) -> bool:
        print("☠ LEVEL 3: SECURE - Double-kexec firmware access")
        print("=" * 50)
        print("This provides secure firmware access via double-kexec:")
        print("  1. ☠ Temporarily unlock hardware access")
        print("  2. ☠ Perform firmware operations")
        print("  3. ☠ Automatically re-enable security")
        print()
        print("☠ Safe: Security automatically restored")
        print("☠ Temporary: Minimal attack window")
        print("☠ Advanced: Requires kernel kexec capability")
        print("☠ Temporary reboot: Quick kexec operations")
        print()

        if not self.confirm_escalation("use double-kexec for secure firmware access"):
            return False

        clean_firmware = self.project_root / "drivers/G615LPAS.325"
        if not clean_firmware.exists() and not self.dry_run:
            print(f"☠ Clean firmware image not found at {clean_firmware}")
            print("   This is required for secure firmware operations.")
            return False

        print("☠ Available secure firmware operations:")
        print("  [1] Backup current firmware securely")
        print("  [2] Read firmware for analysis")
        print("  [3] Write clean firmware (DANGEROUS)")
        print("  [4] Skip to next level")

        if self.auto_approve:
            choice = "1"
            print("☠ Auto-approve enabled: defaulting to option [1] (backup).")
        else:
            choice = input("Select operation [1-4]: ").strip()

        if choice == "4":
            return False
        if choice not in {"1", "2", "3"}:
            print("Invalid choice.")
            return False

        cmd = ["sudo", "bash", "dev/tools/secure-firmware-access.sh"]
        if choice == "1":
            cmd.extend(["--backup", "current-firmware.bin"])
            desc = "Backing up firmware securely"
        elif choice == "2":
            cmd.extend(["--read", "suspicious-firmware.bin"])
            desc = "Reading firmware for analysis"
        else:
            print("☠ WARNING: This will overwrite your firmware!")
            if not self.confirm_escalation("write clean firmware (DANGEROUS)"):
                return False
            cmd.extend(["--write", str(clean_firmware)])
            desc = "Writing clean firmware"

        input_text = "y\n" if self.auto_approve and not self.dry_run else None
        _, _, returncode = self.run_command(
            cmd,
            level_record=level_record,
            description=desc,
            capture_output=False,
            input_text=input_text,
        )
        if returncode != 0:
            return False

        print()
        print("☠ Secure firmware operation completed!")
        return not self.dry_run

    def _ensure_nuclearboot_efi(self, level_record: Dict[str, Any]) -> bool:
        efi_root = self.project_root / "NuclearBootEdk2.efi"
        if efi_root.exists():
            return True
        efi_staging = self.project_root / "staging/boot/NuclearBootEdk2.efi"
        if not efi_staging.exists():
            return False
        _, _, rc = self.run_command(
            ["cp", str(efi_staging), str(efi_root)],
            level_record=level_record,
            description="Staging NuclearBootEdk2.efi in project root",
            allow_in_dry_run=False,
        )
        return rc == 0

    def level_4_vm(self, level_record: Dict[str, Any]) -> bool:
        print("☠ LEVEL 4: VM - KVM recovery environment")
        print("=" * 50)
        print("This reboots into a PhoenixGuard recovery environment:")
        print("  • Clean Ubuntu VM for safe operations")
        print("  • Hardware passthrough for firmware access")
        print("  • Isolated environment prevents re-infection")
        print("  • User can continue work while system repairs")
        print()
        print("☠ Isolated: VM cannot be infected by host bootkits")
        print("☠ Functional: Full desktop environment for productivity")
        print("☠ Reboot: System will restart automatically")
        print("☠ Advanced: Requires IOMMU and passthrough configuration")
        print()

        if not self.confirm_escalation("reboot to KVM recovery environment"):
            return False

        base_image = self.project_root / "ubuntu-24.04-minimal-cloudimg-amd64.qcow2"
        if not base_image.exists() and not self.dry_run:
            print("☠ No recovery VM image found!")
            print("   Download required: ubuntu-24.04-minimal-cloudimg-amd64.qcow2")
            return False

        if not self._ensure_nuclearboot_efi(level_record) and not self.dry_run:
            print("☠ NuclearBootEdk2.efi not found!")
            print("   Run './pf.py build-build' first to prepare PhoenixGuard.")
            return False

        print("☠ FINAL WARNING: System will reboot automatically!")
        print("   After reboot:")
        print("   1. PhoenixGuard menu will appear")
        print("   2. Select 'KVM Snapshot Jump' to launch recovery VM")
        print("   3. Run 'bootkit-scan' in VM for comprehensive analysis")
        print("   4. Use VM to fix infected bootloaders safely")
        print("   5. Run reboot-to-metal when done to return to normal")
        print()

        proceed = "y" if self.auto_approve else input("Proceed with reboot? [y/N]: ").strip().lower()
        if proceed == "y":
            _, _, returncode = self.run_command(
                ["sudo", "bash", "scripts/recovery/reboot-to-vm.sh"],
                level_record=level_record,
                description="Rebooting to VM recovery environment",
                capture_output=False,
            )
            return returncode == 0 and not self.dry_run
        return False

    def level_5_xen(self, level_record: Dict[str, Any]) -> bool:
        print("☠ LEVEL 5: XEN - Xen dom0 with hardware passthrough")
        print("=" * 50)
        print("This provides ultimate isolation via Xen hypervisor.")
        print("☠ Complex: Requires Xen installation and host-specific setup")
        print()

        if not self.confirm_escalation("prepare Xen hypervisor recovery environment"):
            return False

        xen_exists = os.path.exists("/usr/lib/xen-4.17/boot/xen.efi") or os.path.exists("/boot/efi/EFI/xen.efi")
        if not xen_exists and not self.dry_run:
            print("☠ Xen hypervisor not found!")
            print("   Install with: sudo apt install xen-hypervisor-amd64")
            return False

        message = (
            "Automated Xen staging is not currently available in production tasks; "
            "skipping to next level."
        )
        print(f"☠ {message}")
        self._record_step(
            level_record,
            "Xen staging availability",
            ["./pf.py", "workflow-recovery-reboot-vm"],
            "skipped",
            0,
            "",
            message,
        )
        return False

    def level_6_hardware(self, level_record: Dict[str, Any]) -> bool:
        print("☠ LEVEL 6: HARDWARE - Direct SPI flash recovery")
        print("=" * 50)
        print("This bypasses software controls and directly manipulates SPI flash.")
        print("☠ DANGEROUS: Can brick system if it fails!")
        print("☠ EXTREME: Requires hardware programming knowledge")
        print()

        if not self.confirm_escalation("perform direct hardware firmware recovery (EXTREME DANGER)"):
            return False

        print("☠ FINAL SAFETY CHECK:")
        print("   This operation can permanently brick your system!")
        print("   Do you have a hardware programmer available for recovery?")
        print("   Do you have the exact firmware dump for your hardware?")
        print()

        if self.auto_approve:
            safety_check = "I UNDERSTAND THE RISKS"
            print("☠ Auto-approve enabled: accepting safety phrase.")
        else:
            safety_check = input("Type 'I UNDERSTAND THE RISKS' to proceed: ").strip()
        if safety_check != "I UNDERSTAND THE RISKS":
            print("Hardware recovery cancelled.")
            return False

        firmware_path = self.project_root / "drivers/G615LPAS.325"
        _, _, returncode = self.run_command(
            ["sudo", "bash", "scripts/recovery/hardware-recovery.sh", "--firmware", str(firmware_path)],
            level_record=level_record,
            description="Running direct hardware firmware recovery",
            capture_output=False,
            input_text="y\n" if self.auto_approve and not self.dry_run else None,
        )
        return returncode == 0 and not self.dry_run

    def confirm_escalation(self, action: str) -> bool:
        if self.dry_run:
            print(f"☠ Dry-run: auto-approving step to {action}.")
            return True
        if self.auto_approve:
            print(f"☠ Auto-approve: proceeding to {action}.")
            return True
        response = input(f"☠ Proceed to {action}? [y/N]: ").strip().lower()
        return response == "y"

    def _write_plan(self) -> None:
        self.plan_path.parent.mkdir(parents=True, exist_ok=True)
        self.plan["outputs"]["plan_path"] = str(self.plan_path)
        with self.plan_path.open("w", encoding="utf-8") as handle:
            json.dump(self.plan, handle, indent=2, sort_keys=True)
        print(f"☠ Planfile written: {self.plan_path}")

    def run_progressive_recovery(self) -> bool:
        self.print_banner()
        print("☠ PhoenixGuard will try each recovery method in order of safety.")
        print("   Each level requires confirmation before proceeding.")
        print()

        levels = [
            (1, "DETECT", "Software scanning (safest)", self.level_1_detect),
            (2, "SOFT", "ESP recovery deployment", self.level_2_soft),
            (3, "SECURE", "Double-kexec firmware access", self.level_3_secure),
            (4, "VM", "KVM recovery environment", self.level_4_vm),
            (5, "XEN", "Xen hypervisor isolation", self.level_5_xen),
            (6, "HARDWARE", "Direct SPI flash recovery", self.level_6_hardware),
        ]

        overall_success = False
        selected_levels = [item for item in levels if self.only_level is None or item[0] == self.only_level]

        for level_num, name, description, handler in selected_levels:
            print(f"\n{'=' * 60}")
            print(f"☠ LEVEL {level_num}: {description.upper()}")
            print(f"{'=' * 60}")
            level_record = self._start_level(level_num, name, description)

            try:
                success = handler(level_record)
                self._end_level(level_record, success)
                if success:
                    print(f"\n☠ Level {level_num} completed successfully!")
                    if not self.dry_run:
                        overall_success = True
                        if self.only_level is None:
                            break
            except KeyboardInterrupt:
                self._end_level(level_record, False, "cancelled-by-user")
                self.plan["errors"].append({"level": level_num, "error": "cancelled-by-user"})
                print("\n\n☠ Recovery cancelled by user.")
                return False
            except Exception as exc:
                self._end_level(level_record, False, str(exc))
                self.plan["errors"].append({"level": level_num, "error": str(exc)})
                print(f"\n☠ Level {level_num} failed: {exc}")
                print("   Continuing to next escalation level...")

        if self.dry_run:
            print("\n☠ Dry-run complete. Review the generated planfile.")
            return True

        if overall_success:
            print("\n☠ PhoenixGuard recovery workflow complete.")
            return True

        print("\n☠ All selected escalation levels attempted.")
        print("☠ If system is still infected, consider:")
        print("  • Professional malware analysis service")
        print("  • Hardware replacement (motherboard)")
        print("  • Complete system rebuild from scratch")
        return False

    def close(self) -> None:
        self._write_plan()


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="PhoenixGuard progressive recovery orchestrator")
    parser.add_argument("--dry-run", action="store_true", help="Generate planfile without making changes")
    parser.add_argument("--yes", action="store_true", help="Auto-approve prompts")
    parser.add_argument("--level", type=int, choices=[1, 2, 3, 4, 5, 6], help="Run a single escalation level")
    parser.add_argument("--plan-path", help="Custom planfile output path")
    parser.add_argument(
        "--iso-path",
        default=os.environ.get("ISO_PATH"),
        help="Path to recovery ISO used by Level 2 (default: ISO_PATH env or repo root ISO)",
    )
    return parser.parse_args(argv)


def main() -> int:
    args = parse_args(sys.argv[1:])
    if os.geteuid() != 0:
        print("☠ Note: Some operations require root privileges.")
        print("   PhoenixGuard will prompt for sudo when needed.")
        print()

    recovery = PhoenixProgressiveRecovery(
        dry_run=args.dry_run,
        auto_approve=args.yes,
        only_level=args.level,
        plan_path=args.plan_path,
        iso_path=args.iso_path,
    )
    try:
        success = recovery.run_progressive_recovery()
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\n\n☠ PhoenixGuard recovery cancelled.")
        return 130
    except Exception as exc:
        recovery.plan["errors"].append({"level": "global", "error": str(exc)})
        print(f"\n☠ Unexpected error in progressive recovery: {exc}")
        return 1
    finally:
        recovery.close()


if __name__ == "__main__":
    sys.exit(main())
