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

import os
import sys
import re
import gzip
import json
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
from datetime import datetime
import argparse


class Severity(Enum):
    """Security severity levels"""
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"


@dataclass
class ConfigCheck:
    """Represents a kernel config security check"""
    name: str
    expected_value: str  # "y", "n", "m", or specific value
    severity: Severity
    category: str
    description: str
    stig_id: Optional[str] = None
    remediation: Optional[str] = None


class KernelHardeningAnalyzer:
    """Analyzer for kernel configuration security"""
    
    # DISA STIG and security best practice checks
    HARDENING_CHECKS = [
        # === Boot Security ===
        ConfigCheck(
            name="CONFIG_SECURITY_LOCKDOWN_LSM",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Boot Security",
            description="Kernel lockdown LSM prevents runtime modifications to kernel",
            stig_id="RHEL-08-010370",
            remediation="Enable CONFIG_SECURITY_LOCKDOWN_LSM=y and boot with lockdown=integrity"
        ),
        ConfigCheck(
            name="CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY",
            expected_value="y",
            severity=Severity.HIGH,
            category="Boot Security",
            description="Force kernel lockdown in integrity mode",
            remediation="Enable CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY=y"
        ),
        ConfigCheck(
            name="CONFIG_MODULE_SIG",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Boot Security",
            description="Kernel module signature verification",
            stig_id="RHEL-08-010370",
            remediation="Enable CONFIG_MODULE_SIG=y"
        ),
        ConfigCheck(
            name="CONFIG_MODULE_SIG_FORCE",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Boot Security",
            description="Require all kernel modules to be validly signed",
            stig_id="RHEL-08-010370",
            remediation="Enable CONFIG_MODULE_SIG_FORCE=y"
        ),
        ConfigCheck(
            name="CONFIG_MODULE_SIG_ALL",
            expected_value="y",
            severity=Severity.HIGH,
            category="Boot Security",
            description="Automatically sign all modules",
            remediation="Enable CONFIG_MODULE_SIG_ALL=y"
        ),
        ConfigCheck(
            name="CONFIG_MODULE_SIG_SHA256",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Boot Security",
            description="Use SHA256 for module signatures (secure)",
            remediation="Enable CONFIG_MODULE_SIG_SHA256=y"
        ),
        ConfigCheck(
            name="CONFIG_KEXEC",
            expected_value="n",
            severity=Severity.HIGH,
            category="Boot Security",
            description="Disable kexec (can bypass secure boot)",
            stig_id="RHEL-08-010372",
            remediation="Disable CONFIG_KEXEC unless specifically needed"
        ),
        ConfigCheck(
            name="CONFIG_HIBERNATION",
            expected_value="n",
            severity=Severity.MEDIUM,
            category="Boot Security",
            description="Disable hibernation (can leak sensitive data)",
            remediation="Disable CONFIG_HIBERNATION"
        ),
        
        # === Memory Security ===
        ConfigCheck(
            name="CONFIG_STRICT_KERNEL_RWX",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Memory Protection",
            description="Mark kernel memory segments as read-only or non-executable",
            remediation="Enable CONFIG_STRICT_KERNEL_RWX=y"
        ),
        ConfigCheck(
            name="CONFIG_STRICT_MODULE_RWX",
            expected_value="y",
            severity=Severity.HIGH,
            category="Memory Protection",
            description="Apply strict RWX to kernel modules",
            remediation="Enable CONFIG_STRICT_MODULE_RWX=y"
        ),
        ConfigCheck(
            name="CONFIG_HARDENED_USERCOPY",
            expected_value="y",
            severity=Severity.HIGH,
            category="Memory Protection",
            description="Harden copying data between kernel and userspace",
            remediation="Enable CONFIG_HARDENED_USERCOPY=y"
        ),
        ConfigCheck(
            name="CONFIG_FORTIFY_SOURCE",
            expected_value="y",
            severity=Severity.HIGH,
            category="Memory Protection",
            description="Detect buffer overflows at compile time",
            remediation="Enable CONFIG_FORTIFY_SOURCE=y"
        ),
        ConfigCheck(
            name="CONFIG_PAGE_TABLE_ISOLATION",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Memory Protection",
            description="Isolate kernel page tables (Meltdown mitigation)",
            remediation="Enable CONFIG_PAGE_TABLE_ISOLATION=y"
        ),
        ConfigCheck(
            name="CONFIG_RANDOMIZE_BASE",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Memory Protection",
            description="Kernel Address Space Layout Randomization (KASLR)",
            stig_id="RHEL-08-010430",
            remediation="Enable CONFIG_RANDOMIZE_BASE=y"
        ),
        ConfigCheck(
            name="CONFIG_RANDOMIZE_MEMORY",
            expected_value="y",
            severity=Severity.HIGH,
            category="Memory Protection",
            description="Randomize kernel memory sections",
            remediation="Enable CONFIG_RANDOMIZE_MEMORY=y"
        ),
        ConfigCheck(
            name="CONFIG_SLAB_FREELIST_RANDOM",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Memory Protection",
            description="Randomize slab allocator freelist",
            remediation="Enable CONFIG_SLAB_FREELIST_RANDOM=y"
        ),
        ConfigCheck(
            name="CONFIG_SLAB_FREELIST_HARDENED",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Memory Protection",
            description="Harden slab allocator freelist",
            remediation="Enable CONFIG_SLAB_FREELIST_HARDENED=y"
        ),
        
        # === Stack Protection ===
        ConfigCheck(
            name="CONFIG_STACKPROTECTOR",
            expected_value="y",
            severity=Severity.HIGH,
            category="Stack Protection",
            description="Enable stack canary protection",
            remediation="Enable CONFIG_STACKPROTECTOR=y"
        ),
        ConfigCheck(
            name="CONFIG_STACKPROTECTOR_STRONG",
            expected_value="y",
            severity=Severity.HIGH,
            category="Stack Protection",
            description="Use strong stack protector",
            remediation="Enable CONFIG_STACKPROTECTOR_STRONG=y"
        ),
        ConfigCheck(
            name="CONFIG_VMAP_STACK",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Stack Protection",
            description="Use virtually-mapped kernel stacks",
            remediation="Enable CONFIG_VMAP_STACK=y"
        ),
        
        # === Access Control ===
        ConfigCheck(
            name="CONFIG_SECURITY",
            expected_value="y",
            severity=Severity.CRITICAL,
            category="Access Control",
            description="Enable Linux Security Module framework",
            remediation="Enable CONFIG_SECURITY=y"
        ),
        ConfigCheck(
            name="CONFIG_SECURITY_SELINUX",
            expected_value="y",
            severity=Severity.HIGH,
            category="Access Control",
            description="Enable SELinux",
            stig_id="RHEL-08-010170",
            remediation="Enable CONFIG_SECURITY_SELINUX=y"
        ),
        ConfigCheck(
            name="CONFIG_SECURITY_APPARMOR",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Access Control",
            description="Enable AppArmor (alternative to SELinux)",
            remediation="Enable CONFIG_SECURITY_APPARMOR=y if not using SELinux"
        ),
        ConfigCheck(
            name="CONFIG_SECURITY_YAMA",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Access Control",
            description="Enable Yama LSM (ptrace restrictions)",
            remediation="Enable CONFIG_SECURITY_YAMA=y"
        ),
        
        # === Debugging Features (should be disabled in production) ===
        ConfigCheck(
            name="CONFIG_DEBUG_FS",
            expected_value="n",
            severity=Severity.HIGH,
            category="Debug Features",
            description="Disable debugfs (exposes kernel internals)",
            remediation="Disable CONFIG_DEBUG_FS in production"
        ),
        ConfigCheck(
            name="CONFIG_KPROBES",
            expected_value="n",
            severity=Severity.MEDIUM,
            category="Debug Features",
            description="Disable kprobes (can be used for rootkits)",
            remediation="Disable CONFIG_KPROBES in production"
        ),
        ConfigCheck(
            name="CONFIG_PROC_KCORE",
            expected_value="n",
            severity=Severity.HIGH,
            category="Debug Features",
            description="Disable /proc/kcore (exposes kernel memory)",
            remediation="Disable CONFIG_PROC_KCORE"
        ),
        ConfigCheck(
            name="CONFIG_MAGIC_SYSRQ",
            expected_value="n",
            severity=Severity.MEDIUM,
            category="Debug Features",
            description="Disable SysRq magic key (can reboot/crash system)",
            remediation="Disable CONFIG_MAGIC_SYSRQ or set kernel.sysrq=0"
        ),
        
        # === Network Security ===
        ConfigCheck(
            name="CONFIG_SYN_COOKIES",
            expected_value="y",
            severity=Severity.HIGH,
            category="Network Security",
            description="Enable SYN cookie protection",
            remediation="Enable CONFIG_SYN_COOKIES=y"
        ),
        ConfigCheck(
            name="CONFIG_STRICT_DEVMEM",
            expected_value="y",
            severity=Severity.HIGH,
            category="Hardware Access",
            description="Restrict access to /dev/mem",
            remediation="Enable CONFIG_STRICT_DEVMEM=y"
        ),
        ConfigCheck(
            name="CONFIG_IO_STRICT_DEVMEM",
            expected_value="y",
            severity=Severity.MEDIUM,
            category="Hardware Access",
            description="Strict /dev/mem access control",
            remediation="Enable CONFIG_IO_STRICT_DEVMEM=y"
        ),
        ConfigCheck(
            name="CONFIG_DEVMEM",
            expected_value="n",
            severity=Severity.HIGH,
            category="Hardware Access",
            description="Completely disable /dev/mem (most secure)",
            remediation="Disable CONFIG_DEVMEM if not needed"
        ),
        
        # === Legacy/Unused Features ===
        ConfigCheck(
            name="CONFIG_LEGACY_PTYS",
            expected_value="n",
            severity=Severity.LOW,
            category="Legacy Features",
            description="Disable legacy PTYs",
            remediation="Disable CONFIG_LEGACY_PTYS"
        ),
        ConfigCheck(
            name="CONFIG_COMPAT_BRK",
            expected_value="n",
            severity=Severity.LOW,
            category="Legacy Features",
            description="Disable compatibility brk()",
            remediation="Disable CONFIG_COMPAT_BRK"
        ),
    ]
    
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
            'total_checks': len(self.HARDENING_CHECKS),
            'passed': 0,
            'failed': 0,
            'findings': [],
            'score': 0,
            'security_level': 'UNKNOWN',
            'categories': {}
        }
        
        # Run all checks
        for check in self.HARDENING_CHECKS:
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
        for check in self.HARDENING_CHECKS:
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
