#!/usr/bin/env python3
"""
AUTONUKE - PhoenixGuard Master Recovery Orchestrator
===================================================

Progressive bootkit recovery system that guides users through escalating
recovery methods from safest software-only approaches to extreme hardware
recovery using external programmers.

Recovery Escalation Levels:
1. ☠ SCAN: Bootkit detection and analysis
2. ☠ SOFT: ESP-based Nuclear Boot ISO recovery  
3. ☠ HARD: Direct hardware firmware recovery
4. ☠ NUKE: External CH341A hardware programmer recovery

Author: PhoenixGuard Framework
License: MIT
"""

import os
import sys
import json
import subprocess
import shlex
import time
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
    
    def __init__(self):
        self.project_root = Path(__file__).parent.parent
        self.log_file = self.project_root / "autonuke_session.log"
        self.session_start = datetime.now()
        
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
    from safe software scanning to potentially destructive hardware
    operations. Each step will ask for confirmation.{Colors.END}

{Colors.CYAN}☠ Recovery Escalation Levels:{Colors.END}
{Colors.GREEN}    1. ☠ SCAN: Bootkit detection and analysis{Colors.END}
{Colors.BLUE}    2. ☠ SOFT: ESP Nuclear Boot ISO recovery{Colors.END}
{Colors.MAGENTA}    3. ☠ HARD: Direct hardware firmware recovery{Colors.END}
{Colors.RED}    4. ☠ NUKE: External CH341A programmer recovery{Colors.END}

"""
        print(banner)
        
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
    
    def run_command(self, cmd: str, shell: bool = False) -> Tuple[int, str, str]:
        """Run a command and return exit code, stdout, stderr.

        Prefer non-shell execution for safety. Shell mode is reserved for
        trusted commands that require shell features.
        """
        self.log(f"Executing: {cmd}")
        try:
            if shell:
                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    cwd=self.project_root,
                )
            else:
                result = subprocess.run(
                    shlex.split(cmd),
                    shell=False,
                    capture_output=True,
                    text=True,
                    cwd=self.project_root,
                )
            return result.returncode, result.stdout, result.stderr
        except Exception as e:
            self.log(f"Command failed: {e}", "ERROR")
            return 1, "", str(e)
    
    def check_prerequisites(self) -> bool:
        """Check if required tools and files are available"""
        self.log("☠ Checking prerequisites...")
        
        required_files = [
            "scripts/validation/scan-bootkits.sh",
            "scripts/validation/detect_bootkit.py",
            "dev/tools/hardware_firmware_recovery.py",
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
        
        if not self.confirm_action("☠ Run comprehensive bootkit scan?", "LOW"):
            return False
            
        # Run bootkit scan
        code, stdout, stderr = self.run_command("./scripts/validation/scan-bootkits.sh")
        
        if code == 0:
            self.log("☠ Bootkit scan completed successfully", "SUCCESS")
            
            # Check if any threats were detected
            scan_results_file = self.project_root / "out" / "logs" / "bootkit_scan_results.json"
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
        
        if not self.confirm_action("☠ Deploy Nuclear Boot recovery ISO to ESP?", "MEDIUM"):
            return False
        
        print()
        print("☠ Level 2 deployment via legacy make targets is not maintained.")
        print("☠ Recommended replacement command:")
        print("   sudo ./pf.py workflow-recovery-reboot-vm")
        print()
        return False
    
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

        if not self.confirm_action(warning_msg, "HIGH"):
            return False
        
        # Run hardware recovery
        code, stdout, stderr = self.run_command(
            "sudo ./scripts/recovery/hardware-recovery.sh --firmware drivers/G615LPAS.325"
        )
        
        if code == 0:
            self.log("☠ Hardware firmware recovery completed successfully", "SUCCESS")
            print(f"{Colors.GREEN}☠ SYSTEM RECOVERED! Hardware firmware restoration successful.{Colors.END}")
            print(f"{Colors.CYAN}☠ Recovery logs available in hardware_recovery_results.json{Colors.END}")
            return True
        else:
            self.log(f"☠ Hardware recovery failed: {stderr}", "ERROR")
            
            if "FLOCKDN" in stderr or "protected" in stderr.lower():
                self.log("☠  Firmware appears to be hardware-locked by bootkit", "WARNING")
                print(f"{Colors.YELLOW}☠ Firmware is hardware-protected. External programmer may be required.{Colors.END}")
                return False
            else:
                self.log("☠ Hardware recovery failed for unknown reasons", "ERROR")
                return False
    
    def level_4_nuclear_option(self) -> bool:
        """Level 4: External CH341A programmer recovery"""
        self.log("☠ LEVEL 4: Nuclear option - External hardware programmer required...")
        
        nuclear_warning = """☠ NUCLEAR OPTION - EXTERNAL PROGRAMMER RECOVERY

This is the ultimate recovery method for systems with firmware
completely locked down by sophisticated bootkits.

REQUIREMENTS:
• CH341A USB programmer or equivalent
• Physical access to SPI flash chip
• Clean firmware image (G615LPAS.325 or equivalent)
• Technical expertise with hardware programming

PROCEDURE:
1. Power down system completely
2. Connect CH341A to SPI flash chip
3. Read current firmware (backup)
4. Flash clean firmware image
5. Verify flash operation
6. Reconnect and test boot

☠  THIS IS THE MOST EXTREME RECOVERY METHOD ☠"""

        if not self.confirm_action(nuclear_warning, "HIGH"):
            return False
        
        print(f"\n{Colors.RED}{Colors.BOLD}☠ ENTERING NUCLEAR RECOVERY MODE ☠{Colors.END}")
        
        # Check for clean firmware
        clean_firmware = self.project_root / "drivers" / "G615LPAS.325"
        if not clean_firmware.exists():
            self.log("☠ Clean firmware image not found in drivers/", "ERROR")
            print(f"{Colors.RED}☠ Clean firmware (G615LPAS.325) not found!{Colors.END}")
            print(f"{Colors.CYAN}Please place clean firmware in: {clean_firmware}{Colors.END}")
            return False
        
        # Provide detailed instructions
        instructions = f"""
{Colors.CYAN}☠ CH341A RECOVERY INSTRUCTIONS:{Colors.END}

{Colors.YELLOW}1. POWER DOWN SYSTEM COMPLETELY{Colors.END}
   • Shut down system
   • Unplug power cable
   • Remove battery (if laptop)

{Colors.YELLOW}2. LOCATE SPI FLASH CHIP{Colors.END}
   • Usually 8-pin SOIC package near CPU/BIOS
   • Common chips: W25Q64, W25Q128, MX25L series

{Colors.YELLOW}3. CONNECT CH341A PROGRAMMER{Colors.END}
   • Use SOIC-8 test clip or remove chip
   • Connect CH341A to chip pins 1-8
   • Connect USB to programming computer

{Colors.YELLOW}4. BACKUP CURRENT FIRMWARE{Colors.END}
   flashrom -p ch341a_spi -r current_firmware_backup.bin

{Colors.YELLOW}5. FLASH CLEAN FIRMWARE{Colors.END}
   flashrom -p ch341a_spi -w {clean_firmware} -V

{Colors.YELLOW}6. VERIFY FLASH{Colors.END}
   flashrom -p ch341a_spi -v {clean_firmware}

{Colors.YELLOW}7. RECONNECT AND TEST{Colors.END}
   • Disconnect CH341A
   • Reassemble system
   • Power on and test boot

{Colors.GREEN}☠ Clean firmware ready: {clean_firmware}{Colors.END}
{Colors.RED}☠  Keep current firmware backup safe!{Colors.END}
"""
        
        print(instructions)
        
        if self.confirm_action("Have you successfully completed CH341A recovery?", "HIGH"):
            self.log("☠ Nuclear recovery completed by user", "SUCCESS")
            print(f"{Colors.GREEN}☠ NUCLEAR RECOVERY COMPLETE!{Colors.END}")
            print(f"{Colors.CYAN}System should now boot with clean firmware.{Colors.END}")
            return True
        else:
            self.log("Nuclear recovery not completed", "WARNING")
            return False
    
    def run_recovery(self):
        """Main recovery orchestration"""
        self.show_banner()
        
        if not self.check_prerequisites():
            print(f"{Colors.RED}☠ Prerequisites check failed. Please install missing components.{Colors.END}")
            sys.exit(1)
        
        self.log("☠ AUTONUKE session started", "SUCCESS")
        
        # Recovery escalation ladder
        levels = [
            ("☠ SCAN", self.level_1_scan),
            ("☠ SOFT", self.level_2_soft_recovery), 
            ("☠ HARD", self.level_3_hardware_recovery),
            ("☠ NUKE", self.level_4_nuclear_option)
        ]
        
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
                    
                    if level_name == "☠ NUKE":
                        print(f"{Colors.RED}☠ All automated recovery methods exhausted.{Colors.END}")
                        print(f"{Colors.CYAN}Manual intervention may be required.{Colors.END}")
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
1. ☠ SCAN: Software-level bootkit detection
2. ☠ SOFT: ESP Nuclear Boot ISO recovery
3. ☠ HARD: Hardware firmware recovery
4. ☠ NUKE: External programmer recovery

Each level will ask for confirmation before proceeding.
Use Ctrl+C to abort at any time.
""")
        sys.exit(0)
    
    autonuke = AutoNuke()
    autonuke.run_recovery()

if __name__ == "__main__":
    main()
