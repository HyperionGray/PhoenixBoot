#!/usr/bin/env python3
"""
PhoenixGuard Progressive Escalation Recovery System

This implements the "Easy Button" approach - automatically tries each recovery 
method from least to most invasive until the system is clean and secure.

Progressive Escalation Ladder:
1. ☠ DETECT: Software-based bootkit scanning and analysis (no changes)
2. ☠ SOFT: ESP Nuclear Boot ISO deployment (software-only, no reboot)  
3. ☠ SECURE: Double-kexec firmware access (temporary, auto-restore security)
4. ☠ VM: Reboot to KVM recovery environment (user continues work in VM)
5. ☠ XEN: Reboot to Xen dom0 with hardware passthrough (ultimate isolation)
6. ☠ HARDWARE: Direct SPI flash recovery (bypass all software)

Each level requires user confirmation and explains the escalation.
Users can stop at any level or let it auto-escalate to success.
"""

import argparse
import os
import sys
import json
import shlex
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional, Sequence, Tuple

class PhoenixProgressiveRecovery:
    TOOL_NAME = "phoenix_progressive"
    TOOL_VERSION = "2.0.0"

    def __init__(self, dry_run: bool = False, auto_yes: bool = False, plan_out: Optional[str] = None):
        self.risk_level = "UNKNOWN"
        self.results = {}
        self.escalation_level = 0
        self.max_level = 6
        self.dry_run = dry_run
        self.auto_yes = auto_yes
        self.plan_out = Path(plan_out) if plan_out else None
        self.run_id = str(uuid.uuid4())

        self.plan = {
            "tool": {
                "name": self.TOOL_NAME,
                "version": self.TOOL_VERSION
            },
            "run": {
                "run_id": self.run_id,
                "created_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
                "dry_run": self.dry_run,
                "auto_yes": self.auto_yes,
                "cwd": os.getcwd(),
                "user": os.environ.get("USER", "unknown"),
            },
            "levels": [],
            "outputs": {
                "logs_dir": "out/logs",
                "plan_path": ""
            },
            "errors": []
        }

    def print_banner(self):
        """Print the PhoenixGuard banner"""
        print("☠ PHOENIXGUARD - Progressive Bootkit Defense & Recovery")
        print("=" * 56)
        print("☠ Intelligent escalation from safest to most extreme recovery methods")
        if self.dry_run:
            print("☠ DRY-RUN mode: commands are logged but not executed")
        if self.auto_yes:
            print("☠ AUTO-YES mode: interactive confirmations use safe defaults")
        print()

    def _render_command(self, cmd: Sequence[str]) -> str:
        return shlex.join([str(part) for part in cmd])

    def run_command(
        self,
        cmd: Sequence[str],
        description: str = "",
        check: bool = True,
        capture_output: bool = True
    ) -> Tuple[str, str, int]:
        """Run commands safely without invoking a shell."""
        if description:
            print(f"☠ {description}")

        rendered_cmd = self._render_command(cmd)
        if self.dry_run:
            print(f"☠ [dry-run] would run: {rendered_cmd}")
            return "", "", 0

        try:
            if capture_output:
                result = subprocess.run(list(cmd), capture_output=True, text=True, check=check)
                return result.stdout, result.stderr, result.returncode
            result = subprocess.run(list(cmd), check=check)
            return "", "", result.returncode
        except subprocess.CalledProcessError as e:
            if check:
                print(f"☠ Command failed: {rendered_cmd}")
                print(f"   Error: {e}")
                return "", str(e), e.returncode
            return "", str(e), e.returncode
        except Exception as e:
            print(f"☠ Unexpected error running: {rendered_cmd}")
            print(f"   Error: {e}")
            return "", str(e), 1

    def prompt_yes_no(self, prompt: str, default: bool = False, force_yes_when_auto: bool = False) -> bool:
        """Prompt for yes/no with automation-friendly defaults."""
        if self.auto_yes:
            auto_response = True if force_yes_when_auto else default
            shown = "y" if auto_response else "n"
            print(f"{prompt} [{'Y/n' if default else 'y/N'}]: {shown} (auto)")
            return auto_response

        response = input(f"{prompt} [{'Y/n' if default else 'y/N'}]: ").strip().lower()
        if not response:
            return default
        return response == "y"

    def prompt_choice(self, prompt: str, choices: Sequence[str], default: str) -> str:
        if self.auto_yes:
            print(f"{prompt}: {default} (auto)")
            return default

        response = input(f"{prompt}: ").strip()
        if response in choices:
            return response
        return default

    def prompt_text(self, prompt: str, default: str = "") -> str:
        if self.auto_yes:
            print(f"{prompt}: {default} (auto)")
            return default
        return input(f"{prompt}: ").strip()

    def _default_plan_path(self) -> Path:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        return Path("plans") / f"phoenix_progressive_{timestamp}.json"

    def write_planfile(self) -> Path:
        """Persist run metadata to a JSON planfile."""
        plan_path = self.plan_out if self.plan_out else self._default_plan_path()
        plan_path.parent.mkdir(parents=True, exist_ok=True)
        self.plan["outputs"]["plan_path"] = str(plan_path)

        with plan_path.open("w", encoding="utf-8") as handle:
            json.dump(self.plan, handle, indent=2, sort_keys=True)

        print(f"☠ Planfile written: {plan_path}")
        return plan_path

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
            
        # Run bootkit detection
        stdout, stderr, returncode = self.run_command(
            ["make", "scan-bootkits"],
            "Running bootkit detection scan"
        )
        
        # Check results
        if os.path.exists("bootkit_scan_results.json"):
            try:
                with open("bootkit_scan_results.json", "r") as f:
                    scan_results = json.load(f)
                    self.risk_level = scan_results.get("risk_level", "UNKNOWN")
                    self.results["level_1_scan"] = scan_results
            except:
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
            
        # Build and deploy recovery ISO
        stdout, stderr, returncode = self.run_command(
            ["make", "build-nuclear-cd"],
            "Building Nuclear Boot recovery ISO"
        )
        if returncode != 0:
            print("☠ Failed to build recovery ISO")
            return False
            
        stdout, stderr, returncode = self.run_command(
            ["sudo", "make", "deploy-esp-iso"],
            "Deploying recovery ISO to ESP"
        )
        if returncode != 0:
            print("☠ Failed to deploy recovery ISO")
            return False
            
        print()
        print("☠ Nuclear Boot recovery deployed successfully!")
        print("☠ Next steps:")
        print("  1. Reboot and select 'PhoenixGuard Nuclear Boot Recovery (Virtual CD)' from GRUB menu")
        print("  2. Or run 'make boot-from-esp-iso' to access tools immediately")
        print()
        
        # Ask if user wants to proceed immediately
        if self.prompt_yes_no("☠ Boot recovery environment now?", default=False):
            self.run_command(["make", "boot-from-esp-iso"], capture_output=False)
            
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
        
        choice = self.prompt_choice("Select operation [1-4]", ["1", "2", "3", "4"], default="4")
        
        if choice == "1":
            cmd = ["sudo", "make", "secure-firmware-access", "ARGS=--backup current-firmware.bin"]
            self.run_command(cmd, "Backing up firmware securely", capture_output=False)
            
        elif choice == "2":
            cmd = ["sudo", "make", "secure-firmware-access", "ARGS=--read suspicious-firmware.bin"]
            self.run_command(cmd, "Reading firmware for analysis", capture_output=False)
            
        elif choice == "3":
            print("☠ WARNING: This will overwrite your firmware!")
            if self.confirm_escalation("write clean firmware (DANGEROUS)"):
                cmd = ["sudo", "make", "secure-firmware-access", f"ARGS=--write {clean_firmware}"]
                self.run_command(cmd, "Writing clean firmware", capture_output=False)
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
                print("☠ Enhanced recovery image not found - creating it...")
                stdout, stderr, rc = self.run_command(["sudo", "scripts/enhance_kvm_recovery.sh"])
                if rc != 0:
                    print("☠ Failed to create enhanced recovery image")
                    print(f"   Using base image: {base_image}")
                    recovery_image = base_image
            else:
                print("☠ No recovery VM image found!")
                print("   Download required: ubuntu-24.04-minimal-cloudimg-amd64.qcow2")
                return False
            
        if not os.path.exists("NuclearBootEdk2.efi"):
            print("☠ NuclearBootEdk2.efi not found!")
            print("   Run 'make build' first to prepare PhoenixGuard.")
            return False
            
        print("☠ FINAL WARNING: System will reboot automatically!")
        print("   After reboot:")
        print("   1. PhoenixGuard menu will appear")
        print("   2. Select 'KVM Snapshot Jump' to launch enhanced recovery VM")
        print("   3. Enhanced VM includes: Python3, flashrom, chipsec, radare2, binwalk")
        print("   4. Run 'bootkit-scan' in VM for comprehensive analysis")
        print("   5. Use VM to fix infected bootloaders safely")
        print("   6. Run 'make reboot-to-metal' when done to return to normal")
        print()
        
        if self.prompt_yes_no("Proceed with reboot?", default=False):
            self.run_command(["sudo", "make", "reboot-to-vm"], capture_output=False)
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
            
        # Install Xen snapshot jump
        stdout, stderr, returncode = self.run_command(
            ["sudo", "make", "install-phoenix"],
            "Installing Xen Snapshot Jump configuration"
        )
        
        if returncode != 0:
            print("☠ Failed to install Xen configuration")
            return False
            
        print("☠ Xen recovery environment prepared!")
        print("☠ System will reboot to Xen hypervisor.")
        print("   After reboot:")
        print("   1. Xen will boot dom0 Linux")
        print("   2. Recovery tools will be available")
        print("   3. Launch domU for safe operations")
        print("   4. Hardware firmware access via dom0")
        print()
        
        if self.prompt_yes_no("Reboot to Xen now?", default=False):
            self.run_command(["sudo", "reboot"], capture_output=False)
            return True
            
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
        
        safety_check = self.prompt_text("Type 'I UNDERSTAND THE RISKS' to proceed", default="")
        if safety_check != "I UNDERSTAND THE RISKS":
            print("Hardware recovery cancelled.")
            return False
            
        # Proceed with hardware recovery
        self.run_command(["make", "hardware-recovery"], capture_output=False)
        return True
        
    def confirm_escalation(self, action):
        """Ask user to confirm escalation to next level"""
        return self.prompt_yes_no(f"☠ Proceed to {action}?", default=False, force_yes_when_auto=True)
        
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

        completed = False
        try:
            for level_num, (icon, description, handler) in enumerate(levels, 1):
                print(f"\n{'='*60}")
                print(f"{icon} LEVEL {level_num}: {description.upper()}")
                print(f"{'='*60}")

                level_entry = {
                    "level": level_num,
                    "icon": icon,
                    "description": description,
                    "ok": False,
                    "error": None
                }
                self.plan["levels"].append(level_entry)

                try:
                    success = handler()
                    level_entry["ok"] = bool(success)
                    if success:
                        print(f"\n☠ Level {level_num} completed successfully!")
                        print("☠ PhoenixGuard recovery workflow complete.")

                        if level_num < 4:  # Software-only levels
                            print("\n☠ Recommended next steps:")
                            print("  1. Verify system integrity with additional scans")
                            print("  2. Monitor system behavior for anomalies")
                            print("  3. Consider upgrading to hardware-based protection")

                        completed = True
                        break

                except KeyboardInterrupt:
                    print("\n\n☠ Recovery cancelled by user.")
                    level_entry["error"] = "cancelled by user"
                    break
                except Exception as e:
                    print(f"\n☠ Level {level_num} failed: {e}")
                    print("   Continuing to next escalation level...")
                    level_entry["error"] = str(e)

            if not completed:
                print("\n☠ All escalation levels attempted.")
                print("☠ If system is still infected, consider:")
                print("  • Professional malware analysis service")
                print("  • Hardware replacement (motherboard)")
                print("  • Complete system rebuild from scratch")

            return completed
        finally:
            self.write_planfile()

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="PhoenixGuard Progressive Recovery")
    parser.add_argument("--dry-run", action="store_true", help="Record and simulate actions without executing commands")
    parser.add_argument("--auto-yes", action="store_true", help="Use automation defaults for prompts")
    parser.add_argument("--plan-out", help="Write planfile to an explicit path")
    args = parser.parse_args()

    if os.geteuid() != 0:
        print("☠  Note: Some operations require root privileges.")
        print("   PhoenixGuard will prompt for sudo when needed.")
        print()

    # Dry-run should never block on prompts in automation environments.
    auto_yes = args.auto_yes or args.dry_run
    recovery = PhoenixProgressiveRecovery(dry_run=args.dry_run, auto_yes=auto_yes, plan_out=args.plan_out)
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
