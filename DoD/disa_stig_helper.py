#!/usr/bin/env python3
"""
PhoenixBoot DoD helper for DISA STIG-aligned hardening workflows.
"""

from __future__ import annotations

import argparse
import os
import shlex
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from utils.kernel_config_profiles import generate_config_fragment


DISTRO_PROFILES = {
    "rhel": {
        "aliases": {"rhel", "redhat", "red hat", "rocky", "almalinux", "centos", "fedora", "ol", "oracle"},
        "label": "RHEL-like",
        "default_profile": "hardened",
        "package_manager": "dnf/yum",
        "bootloader_update": "grub2-mkconfig -o /boot/grub2/grub.cfg",
        "compliance_focus": "Closest fit to published DISA RHEL STIG content and control language.",
        "security_focus": "Prefer SELinux enforcing, signed modules, and kernel lockdown in integrity or confidentiality mode.",
    },
    "ubuntu": {
        "aliases": {"ubuntu", "debian", "linuxmint", "pop", "pop_os", "neon"},
        "label": "Ubuntu/Debian-like",
        "default_profile": "hardened",
        "package_manager": "apt",
        "bootloader_update": "update-grub",
        "compliance_focus": "Map the host to equivalent DISA/CIS controls and validate Ubuntu-specific package and service defaults.",
        "security_focus": "AppArmor is the common default; add SELinux only when your mission tooling or policy requires it.",
    },
    "generic": {
        "aliases": set(),
        "label": "Generic Linux",
        "default_profile": "hardened",
        "package_manager": "distribution package manager",
        "bootloader_update": "distribution-specific grub regeneration command",
        "compliance_focus": "Use DISA STIG controls as the baseline, then map package, service, and auth settings for the local distro.",
        "security_focus": "Keep security goals separate from pure checklist compliance and validate the effective kernel/runtime posture.",
    },
}


def load_os_release() -> dict[str, str]:
    """Parse /etc/os-release into a dictionary, or return an empty mapping if absent."""
    data: dict[str, str] = {}
    os_release = Path("/etc/os-release")
    if not os_release.exists():
        return data

    for line in os_release.read_text().splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key] = parse_os_release_value(value)
    return data


def parse_os_release_value(value: str) -> str:
    """Parse an os-release value with shell-style quoting, falling back to simple trimming."""
    try:
        tokens = shlex.split(value, posix=True)
    except ValueError:
        return value.strip().strip('"')
    return " ".join(tokens) if tokens else ""


def tokenize_distro_fields(raw_id: str, raw_like: str) -> set[str]:
    """Combine distro ID fields into normalized tokens for family matching."""
    combined = f"{raw_id} {raw_like}".replace("-", " ").strip()
    return {token for token in combined.split() if token}


def detect_distro(requested: str | None = None) -> dict[str, str]:
    """Detect distro family metadata, allowing an explicit override via argument or environment."""
    requested = requested or os.environ.get("DISTRO")
    if requested:
        raw_id = requested.lower()
        raw_like = requested.lower()
        pretty_name = requested
    else:
        os_release = load_os_release()
        raw_id = os.environ.get("DISTRO_ID", os_release.get("ID", "")).lower()
        raw_like = os.environ.get("DISTRO_LIKE", os_release.get("ID_LIKE", "")).lower()
        pretty_name = os.environ.get("DISTRO_NAME", os_release.get("PRETTY_NAME", raw_id or "Unknown Linux"))

    tokens = tokenize_distro_fields(raw_id, raw_like)
    for family, metadata in DISTRO_PROFILES.items():
        if tokens & metadata["aliases"]:
            return {
                "id": raw_id or family,
                "pretty_name": pretty_name,
                "family": family,
                **{k: v for k, v in metadata.items() if k != "aliases"},
            }

    return {
        "id": raw_id or "generic",
        "pretty_name": pretty_name,
        "family": "generic",
        **{k: v for k, v in DISTRO_PROFILES["generic"].items() if k != "aliases"},
    }


def print_guidance(context: dict[str, str]) -> None:
    """Print distro-specific compliance and security guidance to stdout."""
    print(f"Distribution: {context['pretty_name']}")
    print(f"Distro family: {context['label']}")
    print(f"Compliance focus: {context['compliance_focus']}")
    print(f"Security focus: {context['security_focus']}")
    print(f"Package manager: {context['package_manager']}")
    print(f"Bootloader update: {context['bootloader_update']}")


def generate_secure_config(output: Path, requested_distro: str | None, requested_profile: str | None) -> int:
    """Generate a distro-aware kernel config fragment and return 0 on success."""
    context = detect_distro(requested_distro)
    profile = requested_profile or os.environ.get("PROFILE") or context["default_profile"]
    config_text, warnings = generate_config_fragment(profile)

    header = [
        "# PhoenixBoot DoD helper output",
        "# DISA STIG-aligned secure kernel configuration fragment",
        f"# Distro: {context['pretty_name']}",
        f"# Distro family: {context['label']}",
        f"# Compliance focus: {context['compliance_focus']}",
        f"# Security focus: {context['security_focus']}",
        f"# Package manager: {context['package_manager']}",
        f"# Bootloader update: {context['bootloader_update']}",
    ]

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(header) + "\n\n" + config_text.rstrip() + "\n")

    print(f"✓ Generated {profile} secure config: {output}")
    print_guidance(context)
    if warnings:
        print("Warnings:")
        for warning in warnings:
            print(f"  - {warning}")
    return 0


def run_kernel_check(config_path: str | None, output_format: str, requested_distro: str | None, output: str | None) -> int:
    """Run the kernel hardening analyzer with distro-aware guidance and return its exit code."""
    context = detect_distro(requested_distro)
    print_guidance(context)
    print("")

    command = [sys.executable, str(REPO_ROOT / "utils" / "kernel_hardening_analyzer.py")]
    if config_path:
        command.extend(["--config", config_path])
    else:
        command.append("--auto")
    command.extend(["--format", output_format])
    if output:
        command.extend(["--output", output])

    result = subprocess.run(command, cwd=REPO_ROOT)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="PhoenixBoot DoD DISA STIG helper")
    subparsers = parser.add_subparsers(dest="command")

    info_parser = subparsers.add_parser("info", help="Show distro-aware DoD guidance")
    info_parser.add_argument("--distro", help="Override distro detection for output")

    check_parser = subparsers.add_parser("check", help="Run the kernel hardening analyzer with distro-aware guidance")
    check_parser.add_argument("--distro", help="Override distro detection for output")
    check_parser.add_argument("--config", default=os.environ.get("CONFIG_PATH"), help="Kernel config path")
    check_parser.add_argument("--format", choices=["text", "json"], default=os.environ.get("FORMAT", "text"), help="Output format")
    check_parser.add_argument("--output", default=os.environ.get("OUTPUT"), help="Optional report output path")

    config_parser = subparsers.add_parser("generate-secure-config", help="Generate a distro-aware secure kernel config fragment")
    config_parser.add_argument("--distro", help="Override distro detection for generation")
    config_parser.add_argument("--profile", choices=["permissive", "balanced", "hardened"], help="Kernel config profile")
    config_parser.add_argument("--output", default=os.environ.get("OUTPUT", str(REPO_ROOT / "out" / "dod" / "secure_kernel.config")), help="Output file")

    args = parser.parse_args()

    if args.command == "info":
        print_guidance(detect_distro(args.distro))
        return 0
    if args.command == "check":
        return run_kernel_check(args.config, args.format, args.distro, args.output)
    if args.command == "generate-secure-config":
        return generate_secure_config(Path(args.output), args.distro, args.profile)

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
