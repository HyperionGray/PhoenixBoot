#!/usr/bin/env python3
"""
PhoenixGuard Progressive Escalation Recovery System.

Progressive Escalation Ladder:
1. DETECT: Software-based bootkit scanning and analysis (no changes)
2. SOFT: ESP recovery ISO deployment (software-only, no reboot)
3. SECURE: Double-kexec firmware access (temporary, auto-restore security)
4. VM: Reboot to KVM recovery environment (user continues work in VM)
5. XEN: Reboot to Xen dom0 with hardware passthrough (ultimate isolation)
6. HARDWARE: Direct SPI flash recovery (bypass all software)

Each level requires user confirmation and explains the escalation.
Users can stop at any level or let it auto-escalate to success.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, Sequence, Tuple, Union

CommandPart = Union[str, Path]


class PhoenixProgressiveRecovery:
    def __init__(self, assume_yes: bool = False, dry_run: bool = False, max_level: int = 6):
        self.risk_level = "UNKNOWN"
        self.results = {}
        self.escalation_level = 0
        self.max_level = max_level
        self.assume_yes = assume_yes
        self.dry_run = dry_run
        self.repo_root = Path(__file__).resolve().parents[2]

    def print_banner(self):
        """Print the PhoenixGuard banner."""
        print("☠ PHOENIXGUARD - Progressive Bootkit Defense & Recovery")
        print("=" * 56)
        print("☠ Intelligent escalation from safest to most extreme recovery methods")
        if self.dry_run:
            print("☠ DRY RUN mode enabled (commands are printed but not executed)")
        print()

    def run_command(
        self,
        cmd: Sequence[CommandPart],
        description: str = "",
        check: bool = True,
        capture_output: bool = True
    ) -> Tuple[str, str, int]:
        """Run a command with argument-list invocation (no shell)."""
        safe_cmd = [str(part) for part in cmd]
        if description:
            print(f"☠ {description}")
        print(f"☠ Command: {' '.join(safe_cmd)}")

        if self.dry_run:
            return "", "", 0

        try:
            if capture_output:
                result = subprocess.run(
                    safe_cmd,
                    capture_output=True,
                    text=True,
                    check=check,
                    cwd=self.repo_root,
                )
                return result.stdout, result.stderr, result.returncode
            result = subprocess.run(safe_cmd, check=check, cwd=self.repo_root)
            return "", "", result.returncode
        except subprocess.CalledProcessError as err:
            if check:
                print(f"☠ Command failed with exit code {err.returncode}")
                if err.stderr:
                    print(f"   Error: {err.stderr}")
            return err.stdout or "", err.stderr or str(err), err.returncode
        except Exception as err:
            print(f"☠ Unexpected error while running command: {err}")
            return "", str(err), 1

    def _path(self, *parts: str) -> Path:
        return self.repo_root.joinpath(*parts)

    def _read_json_if_present(self, candidates: Sequence[Path]) -> Optional[dict]:
        for candidate in candidates:
            if candidate.exists():
                try:
                    with candidate.open("r", encoding="utf-8") as handle:
                        return json.load(handle)
                except Exception:
                    continue
        return None

    def _prompt(self, message: str, default: str = "") -> str:
        """Prompt with a safe default for non-interactive execution."""
        if self.assume_yes and not sys.stdin.isatty():
            return default
        return input(message).strip()

    def _ensure_recovery_efi_in_repo_root(self) -> bool:
        """Ensure reboot-to-vm helper can find NuclearBootEdk2.efi in repo root."""
        root_efi = self._path("NuclearBootEdk2.efi")
        staging_efi = self._path("staging", "boot", "NuclearBootEdk2.efi")

        if root_efi.exists():
            return True
        if not staging_efi.exists():
            return False

        print("☠ Preparing NuclearBootEdk2.efi in repository root for reboot-to-vm script")
        _, _, rc = self.run_command(["cp", str(staging_efi), str(root_efi)], capture_output=True)
        return rc == 0

    def level_1_detect(self):
        """Level 1: Software-based bootkit detection (safest)"""
        print("☠ LEVEL 1: DETECT - Software-based bootkit scanning")
        print("=" * 50)
        print("This performs comprehensive bootkit detection with zero system changes.")
        print("☠ Safe: No modifications to system")
        print("☠ Fast: Usually completes in under 2 minutes")
        print("☠ Comprehensive: Scans firmware, NVRAM, bootloaders")
        print()
        
        if not self.confirm_escalation("scan for bootkit infections"):
            return False

        scan_script = self._path("scripts", "validation", "scan-bootkits.sh")
        if not scan_script.exists():
            print(f"☠ Missing scan script: {scan_script}")
            return False

        self.run_command(["bash", str(scan_script)], "Running bootkit detection scan")

        # Check results from common output locations.
        scan_results = self._read_json_if_present([
            self._path("bootkit_scan_results.json"),
            self._path("out", "logs", "bootkit_scan_results.json"),
            self._path("scripts", "out", "logs", "bootkit_scan_results.json"),
        ])
        if scan_results:
            self.risk_level = scan_results.get("risk_level", "UNKNOWN")
            self.results["level_1_scan"] = scan_results
        else:
            self.risk_level = "UNKNOWN"
        
        print()
        print(f"☠ Scan Results: Risk Level = {self.risk_level}")
        
        if self.risk_level in ["CLEAN", "LOW"]:
            print("☠ System appears clean! No further escalation needed.")
            print("☠ Recommendation: Continue normal operations with periodic scans.")
            return True
        elif self.risk_level in ["MEDIUM", "HIGH"]:
            print("☠  Potential threats detected. Escalation to Level 2 recommended.")
        elif self.risk_level == "CRITICAL":
            print("☠ CRITICAL threats detected! Immediate escalation recommended.")
        
        print()
        return False  # Continue to next level
        
    def level_2_soft(self):
        """Level 2: ESP Nuclear Boot ISO deployment (software-only)"""
        print("☠ LEVEL 2: SOFT - ESP Nuclear Boot ISO deployment")
        print("=" * 50)
        print("This deploys recovery tools directly to your ESP partition.")
        print("☠ Safe: No system reboots required")
        print("☠ Fast: Software-only deployment")
        print("☠ Persistent: Creates recovery option in boot menu")
        print("☠  Modifies: Adds files to ESP and GRUB configuration")
        print()
        
        if not self.confirm_escalation("deploy Nuclear Boot recovery ISO to ESP"):
            return False
            
        deploy_script = self._path("scripts", "esp-packaging", "deploy-esp-iso.sh")
        boot_script = self._path("scripts", "esp-packaging", "boot-from-esp-iso.sh")
        if not deploy_script.exists():
            print(f"☠ Missing deployment script: {deploy_script}")
            return False

        # Prefer explicit env override for automation, otherwise fallback names.
        recovery_iso = os.environ.get("RECOVERY_ISO")
        if recovery_iso:
            iso_path = Path(recovery_iso).expanduser().resolve()
        else:
            candidates = [
                self._path("PhoenixGuard-Nuclear-Recovery-SB.iso"),
                self._path("PhoenixGuard-Nuclear-Recovery.iso"),
            ]
            iso_path = next((path for path in candidates if path.exists()), None)

        if not iso_path:
            print("☠ Recovery ISO not found.")
            print("   Set RECOVERY_ISO=/path/to/PhoenixGuard-Nuclear-Recovery.iso and retry.")
            return False

        _, _, returncode = self.run_command(
            ["sudo", "bash", str(deploy_script), "--iso", str(iso_path)],
            "Deploying recovery ISO to ESP"
        )
        if returncode != 0:
            print("☠ Failed to deploy recovery ISO")
            return False
            
        print()
        print("☠ Nuclear Boot recovery deployed successfully!")
        print("☠ Next steps:")
        print("  1. Reboot and select 'PhoenixGuard Nuclear Boot Recovery (Virtual CD)' from GRUB menu")
        print("  2. Or run scripts/esp-packaging/boot-from-esp-iso.sh to access tools immediately")
        print()
        
        # Ask if user wants to proceed immediately
        choice = self._prompt("☠ Boot recovery environment now? [y/N]: ", default="n").lower()
        if choice == 'y' and boot_script.exists():
            self.run_command(["bash", str(boot_script)], capture_output=False)
            
        return True  # User can handle recovery from here
        
    def level_3_secure(self):
        """Level 3: Double-kexec firmware access (secure temporary access)"""
        print("☠ LEVEL 3: SECURE - Double-kexec firmware access")
        print("=" * 50)
        print("This provides secure firmware access via double-kexec:")
        print("  1. ☠ Temporarily unlock hardware access")
        print("  2. ☠ Perform firmware operations")  
        print("  3. ☠ Automatically re-enable security")
        print()
        print("☠ Safe: Security automatically restored")
        print("☠ Temporary: Minimal attack window")
        print("☠  Advanced: Requires kernel kexec capability")
        print("☠  Temporary reboot: Quick kexec operations")
        print()
        
        if not self.confirm_escalation("use double-kexec for secure firmware access"):
            return False
            
        # Check for clean firmware image
        clean_firmware = "drivers/G615LPAS.325"
        if not os.path.exists(clean_firmware):
            print(f"☠ Clean firmware image not found at {clean_firmware}")
            print("   This is required for secure firmware operations.")
            return False
            
        print("☠ Available secure firmware operations:")
        print("  [1] Backup current firmware securely")
        print("  [2] Read firmware for analysis")
        print("  [3] Write clean firmware (DANGEROUS)")
        print("  [4] Skip to next level")
        
        default_choice = "1" if self.assume_yes and not sys.stdin.isatty() else ""
        choice = self._prompt("Select operation [1-4]: ", default=default_choice)
        
        if choice == "1":
            self.run_command(
                ["sudo", "bash", str(self._path("dev", "tools", "secure-firmware-access.sh")), "--backup", "current-firmware.bin"],
                "Backing up firmware securely",
                capture_output=False
            )
            
        elif choice == "2":
            self.run_command(
                ["sudo", "bash", str(self._path("dev", "tools", "secure-firmware-access.sh")), "--read", "suspicious-firmware.bin"],
                "Reading firmware for analysis",
                capture_output=False
            )
            
        elif choice == "3":
            print("☠ WARNING: This will overwrite your firmware!")
            if self.confirm_escalation("write clean firmware (DANGEROUS)"):
                self.run_command(
                    ["sudo", "bash", str(self._path("dev", "tools", "secure-firmware-access.sh")), "--write", clean_firmware],
                    "Writing clean firmware",
                    capture_output=False
                )
                print("☠ Firmware recovery completed! System should be clean now.")
                return True
                
        elif choice == "4":
            return False  # Continue to next level
        else:
            print("Invalid choice.")
            return False
            
        print()
        print("☠ Secure firmware operation completed!")
        return True
        
    def level_4_vm(self):
        """Level 4: KVM recovery environment (reboot to recovery VM)"""
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
        print("☠  Reboot: System will restart automatically")
        print("☠  Advanced: Requires IOMMU and passthrough configuration")
        print()
        
        if not self.confirm_escalation("reboot to KVM recovery environment"):
            return False
            
        # Check prerequisites
        recovery_image = "phoenixguard-recovery-enhanced.qcow2"
        base_image = "ubuntu-24.04-minimal-cloudimg-amd64.qcow2"
        
        if not os.path.exists(recovery_image):
            if os.path.exists(base_image):
                enhance_script = self._path("scripts", "enhance_kvm_recovery.sh")
                if enhance_script.exists():
                    print("☠ Enhanced recovery image not found - creating it...")
                    _, _, rc = self.run_command(["sudo", "bash", str(enhance_script)])
                    if rc != 0:
                        print("☠ Failed to create enhanced recovery image")
                        print(f"   Using base image: {base_image}")
                        recovery_image = base_image
                else:
                    print("☠ Enhanced recovery helper not found; using base recovery image.")
                    recovery_image = base_image
            else:
                print("☠ No recovery VM image found!")
                print("   Download required: ubuntu-24.04-minimal-cloudimg-amd64.qcow2")
                return False
            
        if not self._ensure_recovery_efi_in_repo_root():
            print("☠ NuclearBootEdk2.efi not found!")
            print("   Build it first (for example: ./pf.py build-build).")
            return False
            
        print("☠ FINAL WARNING: System will reboot automatically!")
        print("   After reboot:")
        print("   1. PhoenixGuard menu will appear")
        print("   2. Select 'KVM Snapshot Jump' to launch enhanced recovery VM")
        print("   3. Enhanced VM includes: Python3, flashrom, chipsec, radare2, binwalk")
        print("   4. Run 'bootkit-scan' in VM for comprehensive analysis")
        print("   5. Use VM to fix infected bootloaders safely")
        print("   6. Run scripts/recovery/reboot-to-metal.sh when done to return to normal")
        print()
        
        if self._prompt("Proceed with reboot? [y/N]: ", default="n").lower() == 'y':
            self.run_command(
                ["sudo", "bash", str(self._path("scripts", "recovery", "reboot-to-vm.sh"))],
                capture_output=False
            )
            return True
            
        return False
        
    def level_5_xen(self):
        """Level 5: Xen dom0 with hardware passthrough (ultimate isolation)"""
        print("☠ LEVEL 5: XEN - Xen dom0 with hardware passthrough")
        print("=" * 50)
        print("This provides the ultimate isolation via Xen hypervisor:")
        print("  • Xen dom0 for complete hardware isolation")
        print("  • GPU/storage passthrough to guest domains")
        print("  • Hypervisor-level protection against bootkits")
        print("  • Professional-grade enterprise security")
        print()
        print("☠ Ultimate isolation: Hypervisor protection")
        print("☠ Full passthrough: Native hardware performance")
        print("☠  Complex: Requires Xen installation and configuration")
        print("☠  Reboot: System will restart to Xen hypervisor")
        print()
        
        if not self.confirm_escalation("deploy Xen hypervisor recovery environment"):
            return False
            
        # Check for Xen availability
        if not os.path.exists("/usr/lib/xen-4.17/boot/xen.efi") and not os.path.exists("/boot/efi/EFI/xen.efi"):
            print("☠ Xen hypervisor not found!")
            print("   Install with: sudo apt install xen-hypervisor-amd64")
            return False
            
        print("☠ Xen automation is not wired in this repository's current task set.")
        print("   Use the VM or hardware recovery levels for now.")
        return False
        
    def level_6_hardware(self):
        """Level 6: Direct SPI flash recovery (extreme hardware access)"""
        print("☠ LEVEL 6: HARDWARE - Direct SPI flash recovery")
        print("=" * 50)
        print("This is the nuclear option - direct hardware firmware manipulation:")
        print("  • Bypasses ALL software that could be compromised")
        print("  • Direct SPI flash chip access via flashrom")
        print("  • Hardware-level recovery using CHIPSEC")
        print("  • External programmer support (CH341A, etc.)")
        print()
        print("☠ Bootkit-proof: Bypasses all software")
        print("☠ Ultimate recovery: Can fix any software corruption")
        print("☠ DANGEROUS: Can brick system if it fails!")
        print("☠ EXTREME: Requires hardware programming knowledge")
        print()
        
        print("☠  This is the most dangerous recovery method!")
        print("   Only proceed if:")
        print("   • You have a hardware programmer as backup")
        print("   • You understand the risks of firmware manipulation")
        print("   • All other methods have failed")
        print()
        
        if not self.confirm_escalation("perform direct hardware firmware recovery (EXTREME DANGER)"):
            return False
            
        # Final safety check
        print("☠ FINAL SAFETY CHECK:")
        print("   This operation can permanently brick your system!")
        print("   Do you have a hardware programmer available for recovery?")
        print("   Do you have the exact firmware dump for your hardware?")
        print()
        
        safety_check = self._prompt("Type 'I UNDERSTAND THE RISKS' to proceed: ", default="")
        if safety_check != "I UNDERSTAND THE RISKS":
            print("Hardware recovery cancelled.")
            return False
            
        # Proceed with hardware recovery
        self.run_command(
            [
                "sudo",
                "bash",
                str(self._path("scripts", "recovery", "hardware-recovery.sh")),
                "--firmware",
                "drivers/G615LPAS.325",
            ],
            capture_output=False
        )
        return True
        
    def confirm_escalation(self, action):
        """Ask user to confirm escalation to next level"""
        if self.assume_yes:
            print(f"☠ Auto-approving action (--yes): {action}")
            return True
        response = input(f"☠ Proceed to {action}? [y/N]: ").strip().lower()
        return response == 'y'
        
    def run_progressive_recovery(self):
        """Run the progressive recovery workflow"""
        self.print_banner()
        
        print("☠ PhoenixGuard will try each recovery method in order of safety:")
        print("   Each level requires your confirmation before proceeding.")
        print("   You can stop at any level or let it escalate to success.")
        print()
        
        # Define recovery levels
        levels = [
            ("☠ DETECT", "Software scanning (safest)", self.level_1_detect),
            ("☠ SOFT", "ESP recovery deployment", self.level_2_soft),
            ("☠ SECURE", "Double-kexec firmware access", self.level_3_secure),
            ("☠ VM", "KVM recovery environment", self.level_4_vm),
            ("☠ XEN", "Xen hypervisor isolation", self.level_5_xen),
            ("☠ HARDWARE", "Direct SPI flash recovery", self.level_6_hardware),
        ]
        
        for level_num, (icon, description, handler) in enumerate(levels, 1):
            if level_num > self.max_level:
                print(f"\n☠ Reached configured max level ({self.max_level}); stopping escalation.")
                return False
            print(f"\n{'='*60}")
            print(f"{icon} LEVEL {level_num}: {description.upper()}")
            print(f"{'='*60}")
            
            try:
                success = handler()
                if success:
                    print(f"\n☠ Level {level_num} completed successfully!")
                    print("☠ PhoenixGuard recovery workflow complete.")
                    
                    if level_num < 4:  # Software-only levels
                        print("\n☠ Recommended next steps:")
                        print("  1. Verify system integrity with additional scans")
                        print("  2. Monitor system behavior for anomalies")
                        print("  3. Consider upgrading to hardware-based protection")
                    
                    return True
                    
            except KeyboardInterrupt:
                print("\n\n☠ Recovery cancelled by user.")
                return False
            except Exception as e:
                print(f"\n☠ Level {level_num} failed: {e}")
                print("   Continuing to next escalation level...")
                
        print("\n☠ All escalation levels attempted.")
        print("☠ If system is still infected, consider:")
        print("  • Professional malware analysis service")
        print("  • Hardware replacement (motherboard)")
        print("  • Complete system rebuild from scratch")
        return False

def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="PhoenixGuard progressive recovery orchestrator"
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Auto-confirm escalation prompts"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them"
    )
    parser.add_argument(
        "--max-level",
        type=int,
        default=6,
        choices=[1, 2, 3, 4, 5, 6],
        help="Maximum escalation level to attempt (default: 6)"
    )
    args = parser.parse_args()

    if os.geteuid() != 0:
        print("☠  Note: Some operations require root privileges.")
        print("   PhoenixGuard will prompt for sudo when needed.")
        print()
    
    recovery = PhoenixProgressiveRecovery(
        assume_yes=args.yes,
        dry_run=args.dry_run,
        max_level=args.max_level,
    )
    try:
        success = recovery.run_progressive_recovery()
        exit_code = 0 if success else 1
    except KeyboardInterrupt:
        print("\n\n☠ PhoenixGuard recovery cancelled.")
        exit_code = 130
    except Exception as e:
        print(f"\n☠ Unexpected error in progressive recovery: {e}")
        exit_code = 1
        
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
