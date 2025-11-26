#!/usr/bin/env python3
"""
PhoenixBoot Kernel Config Remediation Tool
=========================================

Compares kernel configs against hardened baseline and provides remediation
through kernel recompilation with kexec double-jump technique.

Usage:
    python3 kernel_config_remediation.py --current /boot/config-$(uname -r) --diff
    python3 kernel_config_remediation.py --current /boot/config-$(uname -r) --remediate
    python3 kernel_config_remediation.py --check-kexec
"""

import os
import sys
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import argparse
import json


class KernelConfigRemediator:
    """Tool for kernel config remediation with kexec support"""
    
    def __init__(self):
        self.current_config: Dict[str, str] = {}
        self.baseline_config: Dict[str, str] = {}
        self.differences: List[Dict] = []
    
    def load_config_file(self, config_path: Path) -> Dict[str, str]:
        """Load a kernel config file into a dictionary"""
        import gzip
        import re
        
        config_dict = {}
        
        try:
            if config_path.suffix == '.gz':
                with gzip.open(config_path, 'rt') as f:
                    content = f.read()
            else:
                with open(config_path, 'r') as f:
                    content = f.read()
            
            for line in content.split('\n'):
                line = line.strip()
                
                # Match CONFIG_OPTION=value
                match = re.match(r'^(CONFIG_\w+)=(.+)$', line)
                if match:
                    config_dict[match.group(1)] = match.group(2).strip('"')
                
                # Match # CONFIG_OPTION is not set
                match = re.match(r'^# (CONFIG_\w+) is not set$', line)
                if match:
                    config_dict[match.group(1)] = 'n'
            
            return config_dict
            
        except Exception as e:
            print(f"✗ Error loading config: {e}", file=sys.stderr)
            return {}
    
    def load_baseline_from_analyzer(self) -> Dict[str, str]:
        """Load baseline config from kernel_hardening_analyzer"""
        try:
            # Import the analyzer
            sys.path.insert(0, str(Path(__file__).parent))
            from kernel_hardening_analyzer import KernelHardeningAnalyzer
            
            analyzer = KernelHardeningAnalyzer()
            baseline_dict = {}
            
            for check in analyzer.HARDENING_CHECKS:
                baseline_dict[check.name] = check.expected_value
            
            return baseline_dict
            
        except Exception as e:
            print(f"✗ Error loading baseline: {e}", file=sys.stderr)
            return {}
    
    def diff_configs(self, current: Dict[str, str], baseline: Dict[str, str]) -> List[Dict]:
        """Compare current config against baseline"""
        differences = []
        
        for option, expected_value in baseline.items():
            current_value = current.get(option, 'not_set')
            
            if current_value != expected_value:
                differences.append({
                    'option': option,
                    'current': current_value,
                    'expected': expected_value,
                    'action': 'set' if expected_value != 'n' else 'unset'
                })
        
        return differences
    
    def generate_diff_report(self, differences: List[Dict]) -> str:
        """Generate a human-readable diff report"""
        if not differences:
            return "✓ Configuration matches baseline - no changes needed"
        
        lines = []
        lines.append("=" * 80)
        lines.append(f"Kernel Configuration Differences ({len(differences)} changes needed)")
        lines.append("=" * 80)
        
        # Group by action
        to_set = [d for d in differences if d['action'] == 'set']
        to_unset = [d for d in differences if d['action'] == 'unset']
        
        if to_set:
            lines.append(f"\nOptions to ENABLE/SET ({len(to_set)}):")
            lines.append("-" * 80)
            for diff in to_set:
                lines.append(f"  {diff['option']}")
                lines.append(f"    Current:  {diff['current']}")
                lines.append(f"    Expected: {diff['expected']}")
        
        if to_unset:
            lines.append(f"\nOptions to DISABLE/UNSET ({len(to_unset)}):")
            lines.append("-" * 80)
            for diff in to_unset:
                lines.append(f"  {diff['option']}")
                lines.append(f"    Current:  {diff['current']}")
                lines.append(f"    Expected: disabled")
        
        lines.append("\n" + "=" * 80)
        return '\n'.join(lines)
    
    def check_kexec_available(self) -> Tuple[bool, str]:
        """Check if kexec is available and configured"""
        try:
            # Check if kexec command exists
            result = subprocess.run(['which', 'kexec'], 
                                   capture_output=True, text=True)
            if result.returncode != 0:
                return False, "kexec command not found - install kexec-tools"
            
            # Check if kernel supports kexec
            if Path('/sys/kernel/kexec_loaded').exists():
                kexec_loaded = Path('/sys/kernel/kexec_loaded').read_text().strip()
                if kexec_loaded == '1':
                    return True, "kexec is available and a kernel is loaded"
                else:
                    return True, "kexec is available but no kernel loaded yet"
            else:
                # Check via /proc/config.gz or kernel config
                try:
                    result = subprocess.run(['zgrep', 'CONFIG_KEXEC=', '/proc/config.gz'],
                                          capture_output=True, text=True)
                    if 'CONFIG_KEXEC=y' in result.stdout:
                        return True, "kexec is enabled in kernel config"
                    else:
                        return False, "kexec is disabled in kernel config (CONFIG_KEXEC=n)"
                except:
                    return True, "kexec appears to be available (couldn't verify kernel config)"
            
        except Exception as e:
            return False, f"Error checking kexec: {e}"
    
    def generate_remediation_script(self, differences: List[Dict], 
                                   output_path: Path) -> bool:
        """Generate a shell script to apply config changes"""
        script_lines = [
            "#!/bin/bash",
            "# PhoenixBoot Kernel Config Remediation Script",
            "# Generated by kernel_config_remediation.py",
            "",
            "set -euo pipefail",
            "",
            "# Colors",
            'RED="\\033[0;31m"',
            'GREEN="\\033[0;32m"',
            'YELLOW="\\033[1;33m"',
            'NC="\\033[0m"',
            "",
            "echo -e \"${GREEN}PhoenixBoot Kernel Config Remediation${NC}\"",
            "echo",
            "",
            "# Check if running as root",
            "if [ \"$EUID\" -ne 0 ]; then",
            "  echo -e \"${RED}✗ This script must be run as root${NC}\"",
            "  exit 1",
            "fi",
            "",
            "# Get kernel version",
            "KERNEL_VERSION=$(uname -r)",
            "KERNEL_SRC=\"/usr/src/linux-${KERNEL_VERSION}\"",
            "",
            "echo -e \"${YELLOW}Kernel:${NC} ${KERNEL_VERSION}\"",
            "echo -e \"${YELLOW}Source:${NC} ${KERNEL_SRC}\"",
            "echo",
            "",
            "# Check if kernel source exists",
            "if [ ! -d \"${KERNEL_SRC}\" ]; then",
            "  echo -e \"${RED}✗ Kernel source not found at ${KERNEL_SRC}${NC}\"",
            "  echo \"  Install kernel source package for your distribution\"",
            "  exit 1",
            "fi",
            "",
            "cd \"${KERNEL_SRC}\"",
            "",
            "# Backup current config",
            "echo -e \"${YELLOW}Backing up current config...${NC}\"",
            "cp .config .config.backup.$(date +%Y%m%d_%H%M%S)",
            "",
            "# Apply configuration changes",
            f"echo -e \"${{YELLOW}}Applying {len(differences)} configuration changes...${{NC}}\"",
            "",
        ]
        
        # Add config modifications
        for diff in differences:
            option = diff['option']
            expected = diff['expected']
            
            if diff['action'] == 'set':
                script_lines.append(f"# Set {option}={expected}")
                script_lines.append(f"scripts/config --enable {option.replace('CONFIG_', '')}")
                if expected not in ['y', 'm']:
                    script_lines.append(f"scripts/config --set-val {option.replace('CONFIG_', '')} {expected}")
            else:  # unset
                script_lines.append(f"# Unset {option}")
                script_lines.append(f"scripts/config --disable {option.replace('CONFIG_', '')}")
            
            script_lines.append("")
        
        script_lines.extend([
            "# Update config dependencies",
            "echo -e \"${YELLOW}Updating config dependencies...${NC}\"",
            "make olddefconfig",
            "",
            "echo",
            "echo -e \"${GREEN}✓ Configuration changes applied${NC}\"",
            "echo",
            "echo \"Next steps:\"",
            "echo \"  1. Review the updated .config file\"",
            "echo \"  2. Build the kernel: make -j$(nproc)\"",
            "echo \"  3. Install modules: make modules_install\"",
            "echo \"  4. Install kernel: make install\"",
            "echo \"  5. Update bootloader: update-grub or grub-mkconfig\"",
            "echo \"  6. Reboot into new kernel\"",
            "",
            "echo",
            "echo -e \"${YELLOW}For kexec double-jump remediation:${NC}\"",
            "echo \"  See documentation for kexec workflow\"",
        ])
        
        try:
            with open(output_path, 'w') as f:
                f.write('\n'.join(script_lines))
            
            # Make executable
            output_path.chmod(0o755)
            return True
            
        except Exception as e:
            print(f"✗ Error writing script: {e}", file=sys.stderr)
            return False
    
    def check_kernel_lockdown_state(self) -> Tuple[str, str]:
        """Check current kernel lockdown state"""
        lockdown_path = Path('/sys/kernel/security/lockdown')
        
        if not lockdown_path.exists():
            return "disabled", "Kernel lockdown not supported"
        
        try:
            content = lockdown_path.read_text().strip()
            
            if '[none]' in content:
                return "none", "Kernel lockdown is disabled"
            elif '[integrity]' in content:
                return "integrity", "Kernel lockdown in integrity mode (kexec allowed with signature)"
            elif '[confidentiality]' in content:
                return "confidentiality", "Kernel lockdown in confidentiality mode (kexec blocked)"
            else:
                return "unknown", f"Unknown lockdown state: {content}"
        except Exception as e:
            return "error", f"Error reading lockdown state: {e}"
    
    def print_kexec_workflow_guide(self):
        """Print guide for kexec double-jump remediation"""
        print("=" * 80)
        print("Kexec Double-Jump Remediation Workflow")
        print("=" * 80)
        print()
        print("The kexec double-jump technique allows kernel config remediation")
        print("even when kernel lockdown is enabled:")
        print()
        print("Step 1: Prepare alternate kernel")
        print("  - Have a signed kernel available for first kexec")
        print("  - Ensure it has kexec enabled")
        print()
        print("Step 2: Kexec into alternate kernel")
        print("  $ sudo kexec -l /boot/vmlinuz-alternate --initrd=/boot/initrd-alternate")
        print("  $ sudo kexec -e")
        print()
        print("Step 3: While in alternate kernel, modify target kernel")
        print("  - Edit kernel config as needed")
        print("  - Recompile kernel")
        print("  - Sign kernel if using Secure Boot")
        print()
        print("Step 4: Kexec back to modified kernel")
        print("  $ sudo kexec -l /boot/vmlinuz-modified --initrd=/boot/initrd-modified")
        print("  $ sudo kexec -e")
        print()
        print("Note: If kernel hardening disables kexec entirely:")
        print("  - Use traditional reboot method")
        print("  - Consider disabling CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY")
        print("  - Or modify kernel on installation media before boot")
        print("=" * 80)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="PhoenixBoot Kernel Config Remediation Tool"
    )
    
    parser.add_argument('--current', type=str,
                       help='Path to current kernel config')
    parser.add_argument('--baseline', type=str,
                       help='Path to baseline config (default: use built-in)')
    parser.add_argument('--diff', action='store_true',
                       help='Show configuration differences')
    parser.add_argument('--remediate', action='store_true',
                       help='Generate remediation script')
    parser.add_argument('--output', type=str, default='/tmp/kernel_remediation.sh',
                       help='Output path for remediation script')
    parser.add_argument('--check-kexec', action='store_true',
                       help='Check if kexec is available')
    parser.add_argument('--kexec-guide', action='store_true',
                       help='Show kexec double-jump workflow guide')
    parser.add_argument('--json', action='store_true',
                       help='Output in JSON format')
    
    args = parser.parse_args()
    
    remediator = KernelConfigRemediator()
    
    # Check kexec
    if args.check_kexec:
        available, message = remediator.check_kexec_available()
        lockdown_state, lockdown_msg = remediator.check_kernel_lockdown_state()
        
        print("Kexec Availability Check")
        print("=" * 80)
        print(f"Kexec Status: {'✓ Available' if available else '✗ Not Available'}")
        print(f"Message: {message}")
        print()
        print(f"Kernel Lockdown: {lockdown_state}")
        print(f"Message: {lockdown_msg}")
        print()
        
        if lockdown_state == "confidentiality":
            print("⚠ WARNING: Kernel lockdown in confidentiality mode blocks kexec")
            print("  Consider using integrity mode or traditional reboot for remediation")
        
        return 0 if available else 1
    
    # Show kexec guide
    if args.kexec_guide:
        remediator.print_kexec_workflow_guide()
        return 0
    
    # Need current config for other operations
    if not args.current:
        parser.print_help()
        return 0
    
    current_path = Path(args.current)
    if not current_path.exists():
        print(f"✗ Config file not found: {current_path}", file=sys.stderr)
        return 1
    
    # Load configs
    print("Loading configurations...")
    remediator.current_config = remediator.load_config_file(current_path)
    
    if args.baseline:
        baseline_path = Path(args.baseline)
        if not baseline_path.exists():
            print(f"✗ Baseline file not found: {baseline_path}", file=sys.stderr)
            return 1
        remediator.baseline_config = remediator.load_config_file(baseline_path)
    else:
        remediator.baseline_config = remediator.load_baseline_from_analyzer()
    
    if not remediator.current_config or not remediator.baseline_config:
        print("✗ Failed to load configurations", file=sys.stderr)
        return 1
    
    # Compare configs
    remediator.differences = remediator.diff_configs(
        remediator.current_config,
        remediator.baseline_config
    )
    
    # Generate diff report
    if args.diff:
        if args.json:
            print(json.dumps(remediator.differences, indent=2))
        else:
            report = remediator.generate_diff_report(remediator.differences)
            print(report)
        return 0
    
    # Generate remediation script
    if args.remediate:
        if not remediator.differences:
            print("✓ Configuration matches baseline - no remediation needed")
            return 0
        
        output_path = Path(args.output)
        if remediator.generate_remediation_script(remediator.differences, output_path):
            print(f"✓ Remediation script generated: {output_path}")
            print()
            print("To apply changes:")
            print(f"  sudo {output_path}")
            print()
            print("For kexec double-jump workflow:")
            print(f"  {sys.argv[0]} --kexec-guide")
            return 0
        else:
            return 1
    
    # Default: just show diff
    report = remediator.generate_diff_report(remediator.differences)
    print(report)
    return 0


if __name__ == '__main__':
    sys.exit(main())
