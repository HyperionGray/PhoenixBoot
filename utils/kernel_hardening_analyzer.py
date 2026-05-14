#!/usr/bin/env python3
"""
PhoenixBoot Kernel Hardening Analyzer
====================================

Analyzes kernel configuration against DISA STIG standards and best practices.
Provides recommendations for kernel hardening and security improvements.

Based on:
- DISA STIG for Red Hat Enterprise Linux
- Linux Kernel Self Protection Project (KSPP)
- CIS Benchmarks
- NSA Kernel Hardening Guidelines

Requirements: Python 3.8+ (uses walrus operator)

Usage:
    python3 kernel_hardening_analyzer.py --config /boot/config-$(uname -r)
    python3 kernel_hardening_analyzer.py --auto
    python3 kernel_hardening_analyzer.py --generate-baseline > hardened_config.txt
"""

import argparse
from datetime import datetime
import gzip
import json
from pathlib import Path
import re
import sys
from typing import Dict, List, Optional, Tuple

from kernel_hardening_policy import (
    ConfigProfile,
    ConfigCheck,
    HARDENING_CHECKS,
)


class KernelHardeningAnalyzer:
    """Analyzer for kernel configuration security with multiple profiles"""

    def __init__(self, config_path: Optional[Path] = None):
        """Initialize analyzer with optional config path"""
        self.config_path = config_path
        self.config_dict: Dict[str, str] = {}
        self.findings: List[Dict] = []
    
    def find_kernel_config(self) -> Optional[Path]:
        """Automatically find kernel config file"""
        import subprocess
        
        # Get current kernel version
        try:
            kernel_version = subprocess.check_output(['uname', '-r'], text=True).strip()
        except:
            kernel_version = None
        
        # Possible config locations
        locations = [
            Path('/proc/config.gz'),
            Path(f'/boot/config-{kernel_version}') if kernel_version else None,
            Path('/boot/config'),
        ]
        
        for loc in locations:
            if loc and loc.exists():
                return loc
        
        return None
    
    def load_config(self, config_path: Path) -> bool:
        """Load and parse kernel config file"""
        try:
            if config_path.suffix == '.gz':
                with gzip.open(config_path, 'rt') as f:
                    content = f.read()
            else:
                with open(config_path, 'r') as f:
                    content = f.read()
            
            # Parse config options
            for line in content.split('\n'):
                line = line.strip()
                
                # Match CONFIG_OPTION=value
                match = re.match(r'^(CONFIG_\w+)=(.+)$', line)
                if match:
                    self.config_dict[match.group(1)] = match.group(2).strip('"')
                
                # Match # CONFIG_OPTION is not set
                match = re.match(r'^# (CONFIG_\w+) is not set$', line)
                if match:
                    self.config_dict[match.group(1)] = 'n'
            
            return True
            
        except Exception as e:
            print(f"✗ Error loading config: {e}", file=sys.stderr)
            return False
    
    def check_config_option(self, check: ConfigCheck) -> Tuple[bool, str]:
        """Check a single config option"""
        actual_value = self.config_dict.get(check.name, 'not_set')
        
        # Handle "not set" case
        if actual_value == 'not_set':
            if check.expected_value == 'n':
                return True, 'n'
            else:
                return False, 'not_set'
        
        # Handle expected value check
        if check.expected_value == actual_value:
            return True, actual_value
        else:
            return False, actual_value
    
    def analyze(self) -> Dict:
        """Run full security analysis"""
        results = {
            'config_path': str(self.config_path),
            'total_checks': len(HARDENING_CHECKS),
            'passed': 0,
            'failed': 0,
            'findings': [],
            'score': 0,
            'security_level': 'UNKNOWN',
            'categories': {}
        }
        
        # Run all checks
        for check in HARDENING_CHECKS:
            passed, actual_value = self.check_config_option(check)
            
            finding = {
                'name': check.name,
                'category': check.category,
                'expected': check.expected_value,
                'actual': actual_value,
                'passed': passed,
                'severity': check.severity.value,
                'description': check.description,
                'stig_id': check.stig_id,
                'remediation': check.remediation
            }
            
            results['findings'].append(finding)
            
            if passed:
                results['passed'] += 1
            else:
                results['failed'] += 1
            
            # Track by category
            if check.category not in results['categories']:
                results['categories'][check.category] = {'passed': 0, 'failed': 0}
            
            if passed:
                results['categories'][check.category]['passed'] += 1
            else:
                results['categories'][check.category]['failed'] += 1
        
        # Calculate security score (0-100)
        results['score'] = int((results['passed'] / results['total_checks']) * 100)
        
        # Determine security level
        if results['score'] >= 90:
            results['security_level'] = 'EXCELLENT'
        elif results['score'] >= 75:
            results['security_level'] = 'GOOD'
        elif results['score'] >= 50:
            results['security_level'] = 'ACCEPTABLE'
        else:
            results['security_level'] = 'POOR'
        
        return results
    
    def generate_report(self, results: Dict, format: str = 'text') -> str:
        """Generate analysis report"""
        if format == 'json':
            return json.dumps(results, indent=2)
        
        # Text report
        report = []
        report.append("=" * 80)
        report.append("PhoenixBoot Kernel Hardening Analysis Report")
        report.append("=" * 80)
        report.append(f"\nKernel Config: {results['config_path']}")
        report.append(f"Security Score: {results['score']}/100 ({results['security_level']})")
        report.append(f"Checks Passed: {results['passed']}/{results['total_checks']}")
        report.append(f"Checks Failed: {results['failed']}/{results['total_checks']}")
        
        # Summary by category
        report.append("\n" + "=" * 80)
        report.append("Summary by Category")
        report.append("=" * 80)
        for category, stats in results['categories'].items():
            total = stats['passed'] + stats['failed']
            pct = int((stats['passed'] / total) * 100) if total > 0 else 0
            report.append(f"\n{category}:")
            report.append(f"  Passed: {stats['passed']}/{total} ({pct}%)")
        
        # Failed checks
        failed_findings = [f for f in results['findings'] if not f['passed']]
        if failed_findings:
            report.append("\n" + "=" * 80)
            report.append("Failed Security Checks")
            report.append("=" * 80)
            
            # Group by severity
            for severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
                severity_findings = [f for f in failed_findings if f['severity'] == severity]
                if severity_findings:
                    report.append(f"\n{severity} Severity:")
                    for finding in severity_findings:
                        report.append(f"\n  ✗ {finding['name']}")
                        report.append(f"    Category:    {finding['category']}")
                        report.append(f"    Expected:    {finding['expected']}")
                        report.append(f"    Actual:      {finding['actual']}")
                        report.append(f"    Description: {finding['description']}")
                        if finding['stig_id']:
                            report.append(f"    STIG ID:     {finding['stig_id']}")
                        if finding['remediation']:
                            report.append(f"    Remediation: {finding['remediation']}")
        
        report.append("\n" + "=" * 80)
        report.append("End of Report")
        report.append("=" * 80)
        
        return '\n'.join(report)
    
    def generate_hardened_baseline(self) -> str:
        """Generate a hardened kernel config baseline"""
        lines = []
        lines.append("# PhoenixBoot Hardened Kernel Configuration Baseline")
        lines.append("# Based on DISA STIG and security best practices")
        lines.append("# Generated: " + datetime.now().isoformat())
        lines.append("")
        
        # Group by category
        by_category = {}
        for check in HARDENING_CHECKS:
            if check.category not in by_category:
                by_category[check.category] = []
            by_category[check.category].append(check)
        
        for category, checks in sorted(by_category.items()):
            lines.append(f"\n# === {category} ===")
            for check in checks:
                lines.append(f"# {check.description}")
                if check.stig_id:
                    lines.append(f"# STIG: {check.stig_id}")
                
                if check.expected_value == 'n':
                    lines.append(f"# {check.name} is not set")
                else:
                    lines.append(f"{check.name}={check.expected_value}")
                lines.append("")
        
        return '\n'.join(lines)
    
    def get_profile_config(self, profile: ConfigProfile) -> Dict[str, str]:
        """Get kernel configuration for a specific security profile"""
        config = {}
        
        if profile == ConfigProfile.HARDENED:
            # Maximum security configuration - prevents kexec exploitation
            for check in HARDENING_CHECKS:
                config[check.name] = check.expected_value
            
            # Additional hardening for kexec prevention
            config.update({
                "CONFIG_KEXEC": "n",                    # Disable kexec completely
                "CONFIG_KEXEC_FILE": "n",               # Disable file-based kexec
                "CONFIG_HIBERNATION": "n",              # Disable hibernation
                "CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY": "y",  # Force lockdown
                "CONFIG_MODULE_SIG_FORCE": "y",         # Force module signatures
                "CONFIG_SECURITY_LOCKDOWN_LSM": "y",    # Enable lockdown LSM
            })
            
        elif profile == ConfigProfile.PERMISSIVE:
            # Temporarily reduced security for BIOS/firmware access
            # Start with hardened base but selectively disable protections
            for check in HARDENING_CHECKS:
                config[check.name] = check.expected_value
            
            # Disable protections that block firmware access
            config.update({
                "CONFIG_KEXEC": "y",                    # Enable kexec for transitions
                "CONFIG_KEXEC_FILE": "y",               # Enable file-based kexec
                "CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY": "n",  # Disable forced lockdown
                "CONFIG_MODULE_SIG_FORCE": "n",         # Allow unsigned modules temporarily
                "CONFIG_SECURITY_LOCKDOWN_LSM": "n",    # Disable lockdown LSM
                "CONFIG_STRICT_DEVMEM": "n",            # Allow /dev/mem access for flashrom
                "CONFIG_IO_STRICT_DEVMEM": "n",         # Allow I/O memory access
                "CONFIG_DEVKMEM": "y",                  # Enable /dev/kmem for firmware tools
            })
            
        elif profile == ConfigProfile.TRANSITION:
            # Intermediate profile for safe transitions between permissive and hardened
            for check in HARDENING_CHECKS:
                config[check.name] = check.expected_value
            
            # Enable kexec but keep other protections
            config.update({
                "CONFIG_KEXEC": "y",                    # Enable kexec for final transition
                "CONFIG_KEXEC_FILE": "y",               # Enable file-based kexec
                "CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY": "n",  # Allow transition
                "CONFIG_MODULE_SIG_FORCE": "y",         # Keep module signature enforcement
                "CONFIG_SECURITY_LOCKDOWN_LSM": "y",    # Keep lockdown LSM
            })
        
        return config
    
    def generate_profile_config_file(self, profile: ConfigProfile, output_path: Path) -> bool:
        """Generate a kernel config file for a specific profile"""
        try:
            config = self.get_profile_config(profile)
            
            lines = [
                f"# PhoenixBoot Kernel Configuration - {profile.value} Profile",
                f"# Generated on {datetime.now().isoformat()}",
                f"# Profile: {profile.value}",
                "",
            ]
            
            # Add profile description
            if profile == ConfigProfile.HARDENED:
                lines.extend([
                    "# HARDENED PROFILE: Maximum security configuration",
                    "# - Prevents kexec exploitation",
                    "# - Enforces module signatures",
                    "# - Enables all security features",
                    "# - Suitable for production systems",
                    "",
                ])
            elif profile == ConfigProfile.PERMISSIVE:
                lines.extend([
                    "# PERMISSIVE PROFILE: Temporarily reduced security",
                    "# - Allows firmware/BIOS access",
                    "# - Enables kexec for transitions",
                    "# - Disables some protections",
                    "# - FOR TEMPORARY USE ONLY",
                    "",
                ])
            elif profile == ConfigProfile.TRANSITION:
                lines.extend([
                    "# TRANSITION PROFILE: Safe transition configuration",
                    "# - Enables kexec for final hardening",
                    "# - Maintains most security features",
                    "# - Used during double kexec workflow",
                    "",
                ])
            
            # Add configuration options
            for option, value in sorted(config.items()):
                if value == 'n':
                    lines.append(f"# {option} is not set")
                else:
                    lines.append(f"{option}={value}")
            
            # Write to file
            with open(output_path, 'w') as f:
                f.write('\n'.join(lines))
            
            return True
            
        except Exception as e:
            print(f"✗ Error generating profile config: {e}", file=sys.stderr)
            return False
    
    def validate_profile_transition(self, from_profile: ConfigProfile, 
                                   to_profile: ConfigProfile) -> Tuple[bool, str]:
        """Validate if a profile transition is safe and allowed"""
        
        # Define allowed transitions
        allowed_transitions = {
            ConfigProfile.HARDENED: [ConfigProfile.PERMISSIVE],
            ConfigProfile.PERMISSIVE: [ConfigProfile.TRANSITION, ConfigProfile.HARDENED],
            ConfigProfile.TRANSITION: [ConfigProfile.HARDENED],
        }
        
        if to_profile not in allowed_transitions.get(from_profile, []):
            return False, f"Transition from {from_profile.value} to {to_profile.value} not allowed"
        
        # Additional safety checks
        if from_profile == ConfigProfile.PERMISSIVE and to_profile == ConfigProfile.HARDENED:
            return False, "Direct transition from PERMISSIVE to HARDENED not safe - use TRANSITION profile first"
        
        return True, f"Transition from {from_profile.value} to {to_profile.value} is safe"


def main():
    """Main entry point for CLI"""
    parser = argparse.ArgumentParser(
        description="PhoenixBoot Kernel Hardening Analyzer"
    )
    
    parser.add_argument('--config', type=str,
                       help='Path to kernel config file')
    parser.add_argument('--auto', action='store_true',
                       help='Automatically find and analyze current kernel config')
    parser.add_argument('--generate-baseline', action='store_true',
                       help='Generate hardened kernel config baseline')
    parser.add_argument('--generate-profile', choices=['HARDENED', 'PERMISSIVE', 'TRANSITION'],
                       help='Generate kernel config for specific security profile')
    parser.add_argument('--validate-transition', nargs=2, metavar=('FROM', 'TO'),
                       help='Validate profile transition safety (FROM TO)')
    parser.add_argument('--format', choices=['text', 'json'], default='text',
                       help='Output format (default: text)')
    parser.add_argument('--output', type=str,
                       help='Output file (default: stdout)')
    
    args = parser.parse_args()
    
    analyzer = KernelHardeningAnalyzer()
    
    # Generate baseline
    if args.generate_baseline:
        baseline = analyzer.generate_hardened_baseline()
        if args.output:
            with open(args.output, 'w') as f:
                f.write(baseline)
            print(f"✓ Baseline written to {args.output}")
        else:
            print(baseline)
        return 0
    
    # Find config
    if args.auto:
        config_path = analyzer.find_kernel_config()
        if not config_path:
            print("✗ Could not automatically find kernel config", file=sys.stderr)
            return 1
        print(f"ℹ Found kernel config: {config_path}")
    elif args.config:
        config_path = Path(args.config)
        if not config_path.exists():
            print(f"✗ Config file not found: {config_path}", file=sys.stderr)
            return 1
    else:
        parser.print_help()
        return 0
    
    # Load and analyze
    if not analyzer.load_config(config_path):
        return 1
    
    analyzer.config_path = config_path
    results = analyzer.analyze()
    
    # Generate report
    report = analyzer.generate_report(results, args.format)
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"✓ Report written to {args.output}")
    else:
        print(report)
    
    # Exit code based on security level
    if results['security_level'] in ['POOR']:
        return 2
    elif results['security_level'] in ['ACCEPTABLE']:
        return 1
    else:
        return 0


if __name__ == '__main__':
    sys.exit(main())
