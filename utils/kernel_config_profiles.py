#!/usr/bin/env python3
"""
PhoenixBoot - Kernel Configuration Profiles for Secure Boot Enablement
=====================================================================

Generates kernel configuration profiles optimized for different purposes:
- permissive: Allows BIOS flashing and firmware access (for enabling Secure Boot)
- hardened: Maximum security, prevents firmware modification (after Secure Boot is enabled)

Usage:
    python3 kernel_config_profiles.py --profile permissive --output /tmp/permissive.config
    python3 kernel_config_profiles.py --profile hardened --output /tmp/hardened.config
    python3 kernel_config_profiles.py --compare /boot/config-$(uname -r)
"""

import sys
import argparse
from pathlib import Path
from typing import Dict, List, Tuple

# Configuration profiles for different use cases
KERNEL_PROFILES = {
    "permissive": {
        "description": "Permissive kernel for BIOS flashing and Secure Boot enablement",
        "purpose": "Temporary kernel used during double kexec to enable Secure Boot",
        "configs": {
            # Allow hardware access for BIOS flashing
            "CONFIG_DEVMEM": "y",
            "CONFIG_STRICT_DEVMEM": "n",
            "CONFIG_IO_STRICT_DEVMEM": "n",
            
            # Disable kernel lockdown to allow modifications
            "CONFIG_SECURITY_LOCKDOWN_LSM": "n",
            "CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY": "n",
            "CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY": "n",
            
            # Keep kexec enabled for double kexec workflow
            "CONFIG_KEXEC": "y",
            "CONFIG_KEXEC_FILE": "y",
            
            # Still require module signatures (some security)
            "CONFIG_MODULE_SIG": "y",
            "CONFIG_MODULE_SIG_FORCE": "n",  # Don't force, allow flexibility
            
            # Basic memory protections (keep some security)
            "CONFIG_STRICT_KERNEL_RWX": "y",
            "CONFIG_PAGE_TABLE_ISOLATION": "y",
            "CONFIG_RANDOMIZE_BASE": "y",
        },
        "warnings": [
            "This configuration reduces kernel security",
            "Only use temporarily for BIOS modification",
            "Immediately kexec to hardened kernel after enabling Secure Boot",
        ]
    },
    
    "hardened": {
        "description": "Hardened kernel with maximum security (Secure Boot enforced)",
        "purpose": "Production kernel after Secure Boot is enabled",
        "configs": {
            # Block hardware access
            "CONFIG_DEVMEM": "n",
            "CONFIG_STRICT_DEVMEM": "y",
            "CONFIG_IO_STRICT_DEVMEM": "y",
            
            # Enable kernel lockdown in integrity mode
            "CONFIG_SECURITY_LOCKDOWN_LSM": "y",
            "CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY": "y",
            "CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY": "n",  # Integrity mode allows signed kexec
            
            # Disable kexec to prevent kernel bypass
            "CONFIG_KEXEC": "n",
            "CONFIG_KEXEC_FILE": "n",
            "CONFIG_KEXEC_SIG": "n",
            
            # Enforce module signatures
            "CONFIG_MODULE_SIG": "y",
            "CONFIG_MODULE_SIG_FORCE": "y",
            "CONFIG_MODULE_SIG_ALL": "y",
            "CONFIG_MODULE_SIG_SHA256": "y",
            
            # Maximum memory protections
            "CONFIG_STRICT_KERNEL_RWX": "y",
            "CONFIG_STRICT_MODULE_RWX": "y",
            "CONFIG_HARDENED_USERCOPY": "y",
            "CONFIG_FORTIFY_SOURCE": "y",
            "CONFIG_PAGE_TABLE_ISOLATION": "y",
            "CONFIG_RANDOMIZE_BASE": "y",
            "CONFIG_RANDOMIZE_MEMORY": "y",
            
            # Stack protection
            "CONFIG_STACKPROTECTOR": "y",
            "CONFIG_STACKPROTECTOR_STRONG": "y",
            "CONFIG_VMAP_STACK": "y",
            
            # Disable dangerous features
            "CONFIG_HIBERNATION": "n",
            "CONFIG_LEGACY_VSYSCALL_NONE": "y",
            "CONFIG_BINFMT_MISC": "n",
            
            # Debug features off
            "CONFIG_DEBUG_FS": "n",
            "CONFIG_KPROBES": "n",
            "CONFIG_PROC_KCORE": "n",
            "CONFIG_MAGIC_SYSRQ": "n",
            
            # SELinux or AppArmor (choose one)
            "CONFIG_SECURITY_SELINUX": "y",
            "CONFIG_SECURITY_APPARMOR": "y",
            "CONFIG_SECURITY_YAMA": "y",
        },
        "warnings": [
            "This configuration prioritizes security over flexibility",
            "Kernel modifications and kexec are disabled",
            "To modify kernel, traditional reboot is required",
        ]
    },
    
    "balanced": {
        "description": "Balanced kernel with good security and some flexibility",
        "purpose": "General purpose kernel with Secure Boot and some flexibility",
        "configs": {
            # Restrict but don't fully disable hardware access
            "CONFIG_DEVMEM": "y",
            "CONFIG_STRICT_DEVMEM": "y",  # Restrict to system RAM
            "CONFIG_IO_STRICT_DEVMEM": "y",
            
            # Lockdown in integrity mode (allows signed kexec)
            "CONFIG_SECURITY_LOCKDOWN_LSM": "y",
            "CONFIG_LOCK_DOWN_KERNEL_FORCE_INTEGRITY": "y",
            "CONFIG_LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY": "n",
            
            # Allow kexec but require signatures
            "CONFIG_KEXEC": "y",
            "CONFIG_KEXEC_FILE": "y",
            "CONFIG_KEXEC_SIG": "y",
            "CONFIG_KEXEC_SIG_FORCE": "y",
            
            # Enforce module signatures
            "CONFIG_MODULE_SIG": "y",
            "CONFIG_MODULE_SIG_FORCE": "y",
            "CONFIG_MODULE_SIG_ALL": "y",
            
            # Good memory protections
            "CONFIG_STRICT_KERNEL_RWX": "y",
            "CONFIG_HARDENED_USERCOPY": "y",
            "CONFIG_PAGE_TABLE_ISOLATION": "y",
            "CONFIG_RANDOMIZE_BASE": "y",
            
            # Stack protection
            "CONFIG_STACKPROTECTOR_STRONG": "y",
            "CONFIG_VMAP_STACK": "y",
            
            # Disable some dangerous features
            "CONFIG_HIBERNATION": "n",
            "CONFIG_DEBUG_FS": "n",
            "CONFIG_PROC_KCORE": "n",
        },
        "warnings": [
            "This configuration balances security and usability",
            "Allows signed kexec for updates without reboot",
            "Some administrative tasks may require additional steps",
        ]
    }
}


def generate_config_fragment(profile_name: str) -> Tuple[str, List[str]]:
    """Generate a kernel config fragment for the given profile"""
    
    if profile_name not in KERNEL_PROFILES:
        raise ValueError(f"Unknown profile: {profile_name}. Available: {', '.join(KERNEL_PROFILES.keys())}")
    
    profile = KERNEL_PROFILES[profile_name]
    lines = []
    
    # Header
    lines.append("#")
    lines.append(f"# PhoenixBoot Kernel Configuration Profile: {profile_name}")
    lines.append(f"# {profile['description']}")
    lines.append(f"# Purpose: {profile['purpose']}")
    lines.append("#")
    lines.append("")
    
    # Add configurations
    for option, value in sorted(profile['configs'].items()):
        if value == 'y':
            lines.append(f"{option}=y")
        elif value == 'n':
            lines.append(f"# {option} is not set")
        elif value == 'm':
            lines.append(f"{option}=m")
        else:
            lines.append(f"{option}={value}")
    
    return '\n'.join(lines), profile['warnings']


def compare_with_current(config_path: Path, profile_name: str) -> Dict:
    """Compare current kernel config with profile"""
    import re
    
    if profile_name not in KERNEL_PROFILES:
        raise ValueError(f"Unknown profile: {profile_name}")
    
    profile = KERNEL_PROFILES[profile_name]
    current_config = {}
    
    # Load current config
    try:
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()
                
                # Match CONFIG_OPTION=value
                match = re.match(r'^(CONFIG_\w+)=(.+)$', line)
                if match:
                    current_config[match.group(1)] = match.group(2).strip('"')
                
                # Match # CONFIG_OPTION is not set
                match = re.match(r'^# (CONFIG_\w+) is not set$', line)
                if match:
                    current_config[match.group(1)] = 'n'
    
    except Exception as e:
        raise RuntimeError(f"Error reading config: {e}")
    
    # Compare
    differences = []
    matches = []
    
    for option, expected in profile['configs'].items():
        current = current_config.get(option, 'not_set')
        
        if current == expected or (current == 'not_set' and expected == 'n'):
            matches.append({
                'option': option,
                'value': expected,
                'status': 'match'
            })
        else:
            differences.append({
                'option': option,
                'current': current,
                'expected': expected,
                'status': 'mismatch'
            })
    
    return {
        'profile': profile_name,
        'matches': len(matches),
        'differences': len(differences),
        'match_percentage': (len(matches) / len(profile['configs'])) * 100,
        'details': {
            'matches': matches,
            'differences': differences
        }
    }


def print_comparison_report(comparison: Dict):
    """Print a formatted comparison report"""
    
    print("=" * 80)
    print(f"Kernel Configuration Profile Comparison: {comparison['profile']}")
    print("=" * 80)
    print()
    print(f"Match Score: {comparison['match_percentage']:.1f}%")
    print(f"Matching: {comparison['matches']} / {comparison['matches'] + comparison['differences']}")
    print()
    
    if comparison['differences']:
        print(f"Differences ({len(comparison['differences'])}):")
        print("-" * 80)
        for diff in comparison['details']['differences']:
            print(f"  {diff['option']}")
            print(f"    Current:  {diff['current']}")
            print(f"    Expected: {diff['expected']}")
            print()
    
    if comparison['match_percentage'] == 100:
        print("✓ Current configuration matches profile perfectly")
    elif comparison['match_percentage'] >= 80:
        print("⚠ Current configuration is mostly aligned with profile")
    else:
        print("✗ Current configuration differs significantly from profile")
    
    print("=" * 80)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="PhoenixBoot Kernel Configuration Profiles"
    )
    
    parser.add_argument('--profile', type=str,
                       choices=['permissive', 'hardened', 'balanced'],
                       help='Profile to generate or compare')
    parser.add_argument('--output', type=str,
                       help='Output file for config fragment')
    parser.add_argument('--compare', type=str,
                       help='Compare current config with profile')
    parser.add_argument('--list', action='store_true',
                       help='List available profiles')
    
    args = parser.parse_args()
    
    # List profiles
    if args.list:
        print("Available Kernel Configuration Profiles:")
        print("=" * 80)
        for name, profile in KERNEL_PROFILES.items():
            print(f"\n{name}:")
            print(f"  Description: {profile['description']}")
            print(f"  Purpose: {profile['purpose']}")
            print(f"  Configurations: {len(profile['configs'])} settings")
        return 0
    
    # Generate profile
    if args.profile and args.output:
        try:
            config_text, warnings = generate_config_fragment(args.profile)
            
            output_path = Path(args.output)
            with open(output_path, 'w') as f:
                f.write(config_text)
            
            print(f"✓ Generated {args.profile} profile: {output_path}")
            print()
            print("Warnings:")
            for warning in warnings:
                print(f"  ⚠ {warning}")
            print()
            print("To apply this configuration:")
            print(f"  1. Copy to kernel source: cp {output_path} /usr/src/linux/.config")
            print("  2. Update dependencies: make olddefconfig")
            print("  3. Build kernel: make -j$(nproc)")
            print("  4. Install: make modules_install && make install")
            
            return 0
            
        except Exception as e:
            print(f"✗ Error generating profile: {e}", file=sys.stderr)
            return 1
    
    # Compare with current config
    if args.profile and args.compare:
        try:
            config_path = Path(args.compare)
            if not config_path.exists():
                print(f"✗ Config file not found: {config_path}", file=sys.stderr)
                return 1
            
            comparison = compare_with_current(config_path, args.profile)
            print_comparison_report(comparison)
            
            return 0
            
        except Exception as e:
            print(f"✗ Error comparing configs: {e}", file=sys.stderr)
            return 1
    
    # No valid action
    parser.print_help()
    return 0


if __name__ == '__main__':
    sys.exit(main())
