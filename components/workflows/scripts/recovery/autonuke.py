#!/usr/bin/env python3
"""
AUTONUKE - PhoenixGuard Master Recovery Orchestrator
===================================================

Progressive bootkit recovery system that guides users through escalating
recovery methods from direct vendor BIOS reflashing through UUEFI repair
and finally to extreme hardware recovery using external programmers.

Recovery Escalation Levels:
1. ☠ FLASHROM: Direct vendor BIOS reflash
2. ☠ KEXEC: Double-kexec recovery with permissive kernel settings
3. ☠ ESP-CD: ESP-based recovery ISO boot
4. ☠ UUEFI: Targeted EFI repair on next boot
5. ☠ UUEFI-NUKE: Aggressive EFI reset and rebuild
6. ☠ CMOS: Manual motherboard reset guidance
7. ☠ CH341A: External programmer recovery

Author: PhoenixGuard Framework
License: MIT
"""

import os
import sys
import shutil
import subprocess
import shlex
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from datetime import datetime

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

class AutoNuke:
    """Master recovery orchestrator for progressive bootkit elimination"""
    DEFAULT_VENDOR_FIRMWARE = Path("drivers/G615LPAS.325")
    
    def __init__(self):
        self.project_root = self.find_project_root()
        self.log_file = self.project_root / "out" / "logs" / "autonuke_session.log"
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        self.session_start = datetime.now()

    def find_project_root(self) -> Path:
        """Locate the PhoenixBoot project root from the current script location."""
        current = Path(__file__).resolve().parent
        for candidate in [current, *current.parents]:
            if (candidate / "pf.py").exists() and (candidate / "Pfyfile.pf").exists():
                return candidate
        cwd = Path.cwd()
        if (cwd / "pf.py").exists() and (cwd / "Pfyfile.pf").exists():
            return cwd
        raise RuntimeError(
            f"Could not locate PhoenixBoot project root from {current} or current working directory {cwd}"
        )
        
    def log(self, message: str, level: str = "INFO"):
        """Log message to both console and file"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {level}: {message}"
        
        # Console output with colors
        if level == "ERROR":
            print(f"{Colors.RED}{log_entry}{Colors.END}")
        elif level == "WARNING":
            print(f"{Colors.YELLOW}{log_entry}{Colors.END}")
        elif level == "SUCCESS":
            print(f"{Colors.GREEN}{log_entry}{Colors.END}")
        elif level == "INFO":
            print(f"{Colors.CYAN}{log_entry}{Colors.END}")
        else:
            print(log_entry)
            
        # File output
        with open(self.log_file, "a") as f:
            f.write(log_entry + "\n")

    def show_banner(self):
        """Display AUTONUKE banner"""
        banner = f"""
{Colors.RED}{Colors.BOLD}
    ☠
    ☠                  AUTONUKE                     ☠
    ☠            ☠ BOOTKIT OBLITERATOR ☠          ☠
    ☠                                               ☠
    ☠    Progressive Recovery Escalation System     ☠
    ☠
{Colors.END}

{Colors.YELLOW}☠  WARNING: This tool will attempt progressive recovery methods
    from direct vendor BIOS reflashing to potentially destructive hardware
    operations. Each step will ask for confirmation.{Colors.END}

{Colors.CYAN}☠ Recovery Escalation Levels:{Colors.END}
{Colors.GREEN}    1. ☠ FLASHROM: Direct vendor BIOS reflash{Colors.END}
{Colors.BLUE}    2. ☠ KEXEC: Double-kexec firmware recovery{Colors.END}
{Colors.MAGENTA}    3. ☠ ESP-CD: ESP fake-CD recovery environment{Colors.END}
{Colors.CYAN}    4. ☠ UUEFI: Targeted EFI repair on next boot{Colors.END}
{Colors.YELLOW}    5. ☠ UUEFI-NUKE: Aggressive EFI reset and rebuild{Colors.END}
{Colors.WHITE}    6. ☠ CMOS: Manual board reset guidance{Colors.END}
{Colors.RED}    7. ☠ CH341A: External programmer recovery{Colors.END}

        """
        print(banner)

    def print_risk_assessment(self, risk_level: str, likely: str, could_happen: str, worst_case: str,
                              last_resort: bool = False):
        """Display a concrete risk summary for the next action."""
        print(f"{Colors.YELLOW}☠ Risk Level: {risk_level}{Colors.END}")
        print(f"   Most likely: {likely}")
        print(f"   Could happen: {could_happen}")
        print(f"   Worst case: {worst_case}")
        if last_resort:
            print("   Use this only as a last resort after safer steps and backups are exhausted.")
        print()
        
    def confirm_action(self, message: str, danger_level: str = "LOW") -> bool:
        """Get user confirmation with appropriate warnings"""
        colors = {
            "LOW": Colors.GREEN,
            "MEDIUM": Colors.YELLOW,
            "HIGH": Colors.RED
        }
        
        color = colors.get(danger_level, Colors.CYAN)
        
        print(f"\n{color}{Colors.BOLD}{message}{Colors.END}")
        
        if danger_level == "HIGH":
            print(f"{Colors.RED}☠  This operation is potentially DESTRUCTIVE!{Colors.END}")
            response = input(f"{Colors.RED}Type 'I UNDERSTAND' to proceed: {Colors.END}").strip()
            return response == "I UNDERSTAND"
        else:
            response = input(f"{Colors.CYAN}Continue? [y/N]: {Colors.END}").strip().lower()
            return response in ['y', 'yes']
    
    def run_command(
        self,
        cmd: str,
        shell: bool = False,
        env: Optional[Dict[str, str]] = None,
        cwd: Optional[Path] = None,
    ) -> Tuple[int, str, str]:
        """Run a command and return exit code, stdout, stderr.

        Prefer non-shell execution for safety. Shell mode is reserved for
        trusted commands that require shell features.
        """
        self.log(f"Executing: {cmd}")
        try:
            proc_env = os.environ.copy()
            if env:
                proc_env.update(env)
            if shell:
                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    cwd=cwd or self.project_root,
                    env=proc_env,
                )
            else:
                result = subprocess.run(
                    shlex.split(cmd),
                    shell=False,
                    capture_output=True,
                    text=True,
                    cwd=cwd or self.project_root,
                    env=proc_env,
                )
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            self.log(f"Command failed: {e}", "ERROR")
            return 1, "", str(e)
    
    def check_prerequisites(self) -> bool:
        """Check if required tools and files are available"""
        self.log("☠ Checking prerequisites...")
        
        required_files = [
            "pf.py",
            "Pfyfile.pf",
            "hardware.pf",
            "components/core/scripts/uefi-tools/uuefi-install.sh",
            "components/core/scripts/uefi-tools/uuefi-apply.sh",
            "components/workflows/scripts/esp-packaging/deploy-esp-iso.sh",
            "components/workflows/scripts/esp-packaging/boot-from-esp-iso.sh",
            "utils/hardware_firmware_recovery.py",
        ]
        
        missing_files = []
        for file in required_files:
            if not (self.project_root / file).exists():
                missing_files.append(file)
        
        if missing_files:
            self.log(f"☠ Missing required files: {missing_files}", "ERROR")
            return False
            
        # Check for basic tools
        tools = ["python3", "sudo"]
        for tool in tools:
            code, _, _ = self.run_command(f"which {tool}")
            if code != 0:
                self.log(f"☠ Required tool not found: {tool}", "ERROR")
                return False
                
        self.log("☠ Prerequisites check passed", "SUCCESS")
        return True
    
    def level_1_scan(self) -> bool:
        """Level 1: Bootkit detection and analysis"""
        self.log("☠ LEVEL 1: Starting bootkit detection scan...")
        self.print_risk_assessment(
            "LOW",
            "You get scan results without changing firmware, boot entries, or disks.",
            "The scan may fail or miss a deeply hidden threat.",
            "You trust a compromised system for too long and delay stronger recovery."
        )
        
        if not self.confirm_action("☠ Run comprehensive bootkit scan?", "LOW"):
            return False
            
        # Run bootkit scan
        code, stdout, stderr = self.run_command("make scan-bootkits")
        
        if code == 0:
            self.log("☠ Bootkit scan completed successfully", "SUCCESS")
            
            # Check if any threats were detected
            scan_results_file = self.project_root / "bootkit_scan_results.json"
            if scan_results_file.exists():
                with open(scan_results_file, 'r') as f:
                    results = json.load(f)
                
                threats_found = False
                if 'threats_detected' in results and results['threats_detected']:
                    threats_found = True
                    self.log("☠  THREATS DETECTED! Proceeding to next level recommended.", "WARNING")
                    print(f"\n{Colors.RED}☠ BOOTKIT THREATS DETECTED:{Colors.END}")
                    for threat in results.get('detected_threats', []):
                        print(f"  • {threat}")
                else:
                    self.log("☠ No immediate threats detected", "SUCCESS")
                    print(f"{Colors.GREEN}☠ System appears clean at software level{Colors.END}")
                
                return not threats_found  # Return False if threats found (need escalation)
            else:
                self.log("☠  No scan results file found", "WARNING")
                return False
        else:
            self.log(f"☠ Bootkit scan failed: {stderr}", "ERROR")
            return False
    
    def level_2_soft_recovery(self) -> bool:
        """Level 2: ESP-based Nuclear Boot ISO recovery"""
        self.log("☠ LEVEL 2: Preparing ESP Nuclear Boot ISO recovery...")
        self.print_risk_assessment(
            "MEDIUM",
            "PhoenixGuard adds a recovery boot option to the ESP so you can recover later.",
            "ESP or GRUB cleanup may be needed if deployment is interrupted.",
            "A fragile boot configuration may need manual EFI repair before normal boot returns."
        )
        
        if not self.confirm_action("☠ Deploy Nuclear Boot recovery ISO to ESP?", "MEDIUM"):
            return False
        
        # Check if ISO exists, build if needed
        iso_path = self.project_root / "PhoenixGuard-Nuclear-Recovery.iso"
        if not iso_path.exists():
            self.log("☠ Nuclear Boot ISO not found, building...")
            code, stdout, stderr = self.run_command("make build-nuclear-cd")
            if code != 0:
                self.log(f"☠ Failed to build Nuclear Boot ISO: {stderr}", "ERROR")
                return False
        
        # Deploy to ESP
        code, stdout, stderr = self.run_command("make deploy-esp-iso")
        if code != 0:
            self.log(f"☠ Failed to deploy ISO to ESP: {stderr}", "ERROR")
            return False
            
        self.log("☠ Nuclear Boot ISO deployed to ESP", "SUCCESS")
        
        # Offer immediate boot or manual reboot
        print(f"\n{Colors.GREEN}☠ Nuclear Boot recovery environment ready!{Colors.END}")
        print(f"{Colors.CYAN}Options:{Colors.END}")
        print("  1. Boot into recovery environment now (guided)")
        print("  2. Manual reboot to GRUB menu (select PhoenixGuard Recovery)")
        print("  3. Continue to next escalation level")
        
        choice = input(f"{Colors.CYAN}Choose option [1/2/3]: {Colors.END}").strip()
        
        if choice == "1":
            # Try guided boot
            code, stdout, stderr = self.run_command("make boot-from-esp-iso")
            return code == 0
        elif choice == "2":
            print(f"{Colors.YELLOW}☠  Please reboot and select 'PhoenixGuard Nuclear Recovery' from GRUB menu{Colors.END}")
            return True
        else:
            return False  # Continue escalation
    
    def level_3_hardware_recovery(self) -> bool:
        """Level 3: Direct hardware firmware recovery"""
        self.log("☠ LEVEL 3: Preparing hardware-level firmware recovery...")
        
        warning_msg = """☠ HARDWARE FIRMWARE RECOVERY
        
This will attempt to directly access your system's SPI flash chip
to restore clean firmware, bypassing any bootkit protections.

RISKS:
• System may become temporarily unbootable if interrupted
• Requires administrator privileges
• Will overwrite current firmware

        SAFETY MEASURES:
        • Full firmware backup will be created first
        • Recovery can be undone with backup
        • Uses hardware-level verification"""
        self.print_risk_assessment(
            "HIGH",
            "Hardware recovery may restore clean firmware when software remediation fails.",
            "Flash access may fail or leave recovery incomplete, forcing escalation.",
            "A bad write or interruption can brick the board and require external programming.",
            last_resort=True
        )

    def prompt_for_firmware_path(self) -> Optional[Path]:
        """Prompt for a vendor firmware image path."""
        default_path = self.project_root / self.DEFAULT_VENDOR_FIRMWARE
        prompt = f"{Colors.CYAN}Vendor BIOS image path [{default_path if default_path.exists() else '/path/to/vendor-bios.bin'}]: {Colors.END}"
        response = input(prompt).strip()
        if not response and default_path.exists():
            return default_path
        if not response:
            return None
        candidate = Path(response).expanduser().resolve()
        return candidate if candidate.exists() else None

    def detect_esp_path(self) -> Optional[Path]:
        """Best-effort detection of the system ESP mount point."""
        code, stdout, _ = self.run_command("findmnt -t vfat -n -o TARGET")
        if code == 0:
            path = stdout.splitlines()[0].strip() if stdout.strip() else ""
            if path:
                return Path(path)
        fallback = Path("/boot/efi")
        return fallback if fallback.exists() else None

    def get_recovery_levels(self):
        """Return the first-release escalation ladder."""
        return [
            ("☠ FLASHROM", self.level_1_flashrom_restore),
            ("☠ KEXEC", self.level_2_double_kexec_recovery),
            ("☠ ESP-CD", self.level_3_esp_cd_recovery),
            ("☠ UUEFI", self.level_4_uuefi_targeted_recovery),
            ("☠ UUEFI-NUKE", self.level_5_uuefi_nuclear_recovery),
            ("☠ CMOS", self.level_6_manual_board_reset),
            ("☠ CH341A", self.level_7_ch341a_recovery),
        ]

 ☠  THIS IS THE MOST EXTREME RECOVERY METHOD ☠"""
        self.print_risk_assessment(
            "CRITICAL",
            "An external programmer may recover systems locked down beyond software repair.",
            "You may still fail to attach correctly, flash the wrong image, or need repeated attempts.",
            "The board may remain bricked or physically damaged if the process goes wrong.",
            last_resort=True
        )

        return self.ask_if_recovered("After the double-kexec flash + Secure Boot re-hardening, is the system usable?")

    def level_3_esp_cd_recovery(self) -> bool:
        """Level 3: Use the ESP fake-CD recovery environment."""
        self.log("☠ LEVEL 3: Preparing ESP fake-CD recovery...")

        print(f"\n{Colors.BOLD}☠ LEVEL 3: ESP FAKE CD{Colors.END}")
        print("If firmware flashing still needs a cleaner environment, burn the recovery ISO into the ESP and boot it as a one-shot recovery medium.")
        print("That keeps the workflow short while avoiding a normal reboot path as much as possible.")
        print()

        esp_path = self.detect_esp_path()
        iso_path = self.project_root / "PhoenixGuard-Nuclear-Recovery.iso"
        if esp_path and esp_path.exists():
            usage = shutil.disk_usage(esp_path)
            print(f"{Colors.CYAN}ESP detected:{Colors.END} {esp_path}")
            print(f"{Colors.CYAN}ESP free space:{Colors.END} {usage.free // (1024 * 1024)} MiB")
            if iso_path.exists():
                iso_size = iso_path.stat().st_size // (1024 * 1024)
                print(f"{Colors.CYAN}Recovery ISO size:{Colors.END} {iso_size} MiB")
        else:
            print(f"{Colors.YELLOW}☠ ESP auto-detection was inconclusive; verify /boot/efi manually before deploying.{Colors.END}")
        print()

        self.print_recovery_commands([
            "./pf.py workflow-cd-prepare",
            "sudo bash components/workflows/scripts/esp-packaging/deploy-esp-iso.sh --iso PhoenixGuard-Nuclear-Recovery.iso",
            "sudo bash components/workflows/scripts/esp-packaging/boot-from-esp-iso.sh",
        ])
        print("Once the recovery ISO boots, use it to run flashrom from a minimal OS with a vendor BIOS image already downloaded.")
        print("Also leave a small text file there with the exact flash command you want to run from the recovery OS.")
        print()

        if iso_path.exists() and self.confirm_action("Deploy the recovery ISO to the ESP now?", "MEDIUM"):
            code, _, stderr = self.run_command(
                "bash components/workflows/scripts/esp-packaging/deploy-esp-iso.sh --iso PhoenixGuard-Nuclear-Recovery.iso"
            )
            if code != 0:
                self.log(f"☠ ESP ISO deployment failed: {stderr}", "WARNING")
            else:
                self.log("☠ Recovery ISO deployed to ESP", "SUCCESS")

        return self.ask_if_recovered("Did the ESP fake-CD recovery environment let you flash clean firmware successfully?")

    def level_4_uuefi_targeted_recovery(self) -> bool:
        """Level 4: Install and boot UUEFI for targeted EFI repair."""
        self.log("☠ LEVEL 4: Preparing UUEFI targeted recovery...")

        print(f"\n{Colors.BOLD}☠ LEVEL 4: UUEFI TARGETED FIX{Colors.END}")
        print("Now pivot to UUEFI as a second-stage firmware environment.")
        print("This is useful when the vendor firmware is still present but EFI variables or boot paths need hands-on correction.")
        print()
        self.print_recovery_commands([
            "./pf.py uuefi-install",
            "./pf.py uuefi-apply",
            "sudo reboot",
        ])
        print("Inside UUEFI, compare live EFI variables against your expected vendor baseline and fix suspicious entries.")
        print()

        if self.confirm_action("Install and schedule UUEFI for the next boot now?", "MEDIUM"):
            code, _, stderr = self.run_command("./pf.py uuefi-install")
            if code == 0:
                code, _, stderr = self.run_command("./pf.py uuefi-apply")
            if code != 0:
                self.log(f"☠ UUEFI setup failed: {stderr}", "WARNING")
            else:
                self.log("☠ UUEFI installed and scheduled for next boot", "SUCCESS")

        return self.ask_if_recovered("Did UUEFI let you fix the suspicious EFI state without a full wipe?")

    def level_5_uuefi_nuclear_recovery(self) -> bool:
        """Level 5: Use UUEFI for a destructive EFI reset."""
        self.log("☠ LEVEL 5: Preparing UUEFI nuclear recovery...")

        warning = """☠ UUEFI NUCLEAR RESET

Use this only if targeted repair failed.

What this means:
• Wipe EFI variables aggressively
• Rebuild clean boot entries
• Reapply the vendor BIOS image if needed
• Attempt deeper cleanup only when hardware permits it
"""
        print(f"\n{Colors.BOLD}☠ LEVEL 5: UUEFI NUCLEAR{Colors.END}")
        print(warning)
        print("DXE/SPI cleanup is harder and may still require hardware access, so treat this as a risky last software-side step.")
        print()

        return self.confirm_action("Did you complete the UUEFI nuclear wipe and want to stop escalation here?", "HIGH")

    def level_6_manual_board_reset(self) -> bool:
        """Level 6: Manual board-level clearing and recovery instructions."""
        self.log("☠ LEVEL 6: Presenting manual board reset guidance...")

        print(f"\n{Colors.BOLD}☠ LEVEL 6: MANUAL BOARD RESET{Colors.END}")
        print("Before external programmers, try the boring hardware reset path many users skip:")
        print("  • Use the motherboard clear-CMOS / clear-BIOS jumper or button")
        print("  • Remove AC power and the laptop battery if present")
        print("  • Remove the CMOS coin-cell battery")
        print("  • Wait at least a couple of hours before reassembly")
        print("  • Re-enter firmware setup and reflash if your board supports recovery from USB")
        print()

        return self.ask_if_recovered("Did the manual board reset clear the bad boot state?")

    def level_7_ch341a_recovery(self) -> bool:
        """Level 7: External CH341A programmer recovery."""
        self.log("☠ LEVEL 7: Nuclear option - CH341A recovery guidance...")

        clean_firmware = self.project_root / self.DEFAULT_VENDOR_FIRMWARE
        display_firmware = str(clean_firmware if clean_firmware.exists() else Path("/path/to/vendor-bios.bin"))
        print(f"\n{Colors.RED}{Colors.BOLD}☠ LEVEL 7: CH341A / FULL NUCLEAR{Colors.END}")
        print("If the platform is locked into SPI/DXE protections, it is time for an external programmer.")
        print("Email bootkit@hyperiongray.com if you need help or a CH341A after basic verification.")
        print("Alex (_hyp3ri0n / P4X) will do what he can, though OSS support may take a little time.")
        print()
        self.print_recovery_commands([
            "flashrom -p ch341a_spi -r current_firmware_backup.bin",
            f"flashrom -p ch341a_spi -w {shlex.quote(display_firmware)} -V",
            f"flashrom -p ch341a_spi -v {shlex.quote(display_firmware)}",
        ])
        print("Checklist:")
        print("  • Locate the BIOS flash chip (often an 8-pin SOIC device)")
        print("  • Verify clip orientation before attaching power")
        print("  • Be careful with voltage; many chips expect 3.3V and some need ~2V adapters")
        print("  • Keep your backup dump somewhere safe before writing anything")
        print()

        if self.ask_if_recovered("Did the CH341A recovery restore the machine?"):
            self.log("☠ CH341A recovery completed by user", "SUCCESS")
            return True

        print("If that still does not work, contact bootkit@hyperiongray.com and PhoenixBoot will try to help further.")
        return False
    
    def run_recovery(self):
        """Main recovery orchestration"""
        self.show_banner()
        
        if not self.check_prerequisites():
            print(f"{Colors.RED}☠ Prerequisites check failed. Please install missing components.{Colors.END}")
            sys.exit(1)
        
        self.log("☠ AUTONUKE session started", "SUCCESS")
        
        # Recovery escalation ladder
        levels = self.get_recovery_levels()
        
        for level_name, level_func in levels:
            print(f"\n{Colors.BOLD}{'='*60}{Colors.END}")
            print(f"{Colors.BOLD}ESCALATING TO: {level_name}{Colors.END}")
            print(f"{Colors.BOLD}{'='*60}{Colors.END}")
            
            try:
                if level_func():
                    # Success at this level
                    print(f"\n{Colors.GREEN}☠ RECOVERY SUCCESSFUL AT LEVEL: {level_name}{Colors.END}")
                    self.log(f"Recovery completed successfully at level: {level_name}", "SUCCESS")
                    break
                else:
                    # Need to escalate
                    print(f"\n{Colors.YELLOW}☠  Level {level_name} incomplete, escalating...{Colors.END}")
                    self.log(f"Escalating from level: {level_name}", "WARNING")
                    
                    if level_name == "☠ CH341A":
                        print(f"{Colors.RED}☠ All automated recovery methods exhausted.{Colors.END}")
                        print(f"{Colors.CYAN}Manual intervention may be required.{Colors.END}")
                        print(f"{Colors.CYAN}{self.get_secureboot_resilience_message()}{Colors.END}")
                        break
                        
            except KeyboardInterrupt:
                print(f"\n{Colors.YELLOW}☠  Recovery interrupted by user{Colors.END}")
                self.log("Recovery session interrupted", "WARNING")
                break
            except Exception as e:
                self.log(f"Unexpected error in {level_name}: {e}", "ERROR")
                print(f"{Colors.RED}☠ Unexpected error: {e}{Colors.END}")
                continue
        
        # Session summary
        session_duration = datetime.now() - self.session_start
        print(f"\n{Colors.CYAN}☠ AUTONUKE SESSION SUMMARY:{Colors.END}")
        print(f"   Duration: {session_duration}")
        print(f"   Log file: {self.log_file}")
        print(f"   Session: {self.session_start.strftime('%Y-%m-%d %H:%M:%S')}")
        
        self.log("AUTONUKE session completed", "SUCCESS")

def main():
    """Main entry point"""
    if len(sys.argv) > 1 and sys.argv[1] in ['-h', '--help']:
        print("""
AUTONUKE - PhoenixGuard Master Recovery Orchestrator

Usage: python3 autonuke.py

Progressive bootkit recovery system that escalates through:
1. ☠ FLASHROM: Direct vendor BIOS reflash
2. ☠ KEXEC: Double-kexec recovery with permissive kernel settings
3. ☠ ESP-CD: Recovery ISO deployed to ESP as a fake CD
4. ☠ UUEFI: Targeted EFI repair on next boot
5. ☠ UUEFI-NUKE: Aggressive EFI reset and rebuild
6. ☠ CMOS: Manual motherboard reset guidance
7. ☠ CH341A: External programmer recovery

Each level will ask for confirmation before proceeding.
Use Ctrl+C to abort at any time.
""")
        sys.exit(0)
    
    autonuke = AutoNuke()
    autonuke.run_recovery()

if __name__ == "__main__":
    main()
