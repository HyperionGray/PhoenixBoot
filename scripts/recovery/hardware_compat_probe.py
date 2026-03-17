#!/usr/bin/env python3
"""
Hardware compatibility probe for PhoenixGuard recovery flows.

This probe checks host prerequisites for each progressive recovery level and
reports readiness in either human-readable or JSON format.
"""

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _command_exists(command: str) -> bool:
    return shutil.which(command) is not None


def run_probe() -> Dict[str, object]:
    """Run compatibility checks and return a structured report."""
    uefi_mode = Path("/sys/firmware/efi").exists()
    make_present = _command_exists("make")
    sudo_present = _command_exists("sudo")
    qemu_present = _command_exists("qemu-system-x86_64")
    flashrom_present = _command_exists("flashrom")
    kexecctl_present = _command_exists("kexec")
    xen_present = Path("/usr/lib/xen-4.17/boot/xen.efi").exists() or Path("/boot/efi/EFI/xen.efi").exists()
    firmware_image_present = Path("drivers/G615LPAS.325").exists()
    nuclear_boot_present = Path("NuclearBootEdk2.efi").exists()

    kexec_disabled_value = _read_text(Path("/proc/sys/kernel/kexec_load_disabled"))
    kexec_enabled = kexec_disabled_value == "0"

    cmdline = _read_text(Path("/proc/cmdline"))
    iommu_enabled = any(
        token in cmdline
        for token in (
            "intel_iommu=on",
            "amd_iommu=on",
            "iommu=pt",
            "iommu.passthrough=1",
        )
    )

    checks: List[Dict[str, str]] = []
    checks.append(
        {
            "name": "UEFI firmware mode",
            "status": "pass" if uefi_mode else "fail",
            "severity": "blocker",
            "detail": "/sys/firmware/efi is present" if uefi_mode else "System is not in UEFI mode",
            "recommendation": "Boot in UEFI mode before running firmware-focused recovery tooling",
        }
    )
    checks.append(
        {
            "name": "Core build toolchain (make)",
            "status": "pass" if make_present else "fail",
            "severity": "blocker",
            "detail": "make found in PATH" if make_present else "make is missing from PATH",
            "recommendation": "Install make to execute PhoenixGuard task targets",
        }
    )
    checks.append(
        {
            "name": "Privilege escalation tool (sudo)",
            "status": "pass" if sudo_present else "fail",
            "severity": "warning",
            "detail": "sudo found in PATH" if sudo_present else "sudo is missing from PATH",
            "recommendation": "Install/configure sudo for level 2+ operations",
        }
    )
    checks.append(
        {
            "name": "kexec capability",
            "status": "pass" if (kexec_enabled and kexecctl_present) else "fail",
            "severity": "warning",
            "detail": (
                "kexec command available and kernel kexec loading enabled"
                if (kexec_enabled and kexecctl_present)
                else "kexec unavailable or kernel kexec loading disabled"
            ),
            "recommendation": "Enable kexec and install kexec-tools for secure firmware access flows",
        }
    )
    checks.append(
        {
            "name": "IOMMU support for virtualization isolation",
            "status": "pass" if iommu_enabled else "fail",
            "severity": "warning",
            "detail": "IOMMU kernel flags detected" if iommu_enabled else "No IOMMU flags in /proc/cmdline",
            "recommendation": "Enable IOMMU in firmware and kernel args for VM/Xen passthrough features",
        }
    )
    checks.append(
        {
            "name": "QEMU runtime",
            "status": "pass" if qemu_present else "fail",
            "severity": "warning",
            "detail": "qemu-system-x86_64 found in PATH" if qemu_present else "qemu-system-x86_64 missing",
            "recommendation": "Install QEMU to support level 4 VM recovery",
        }
    )
    checks.append(
        {
            "name": "Xen boot artifact",
            "status": "pass" if xen_present else "fail",
            "severity": "warning",
            "detail": "Xen EFI artifact found" if xen_present else "Xen EFI artifact not found",
            "recommendation": "Install xen-hypervisor-amd64 for level 5 Xen isolation",
        }
    )
    checks.append(
        {
            "name": "flashrom utility",
            "status": "pass" if flashrom_present else "fail",
            "severity": "warning",
            "detail": "flashrom found in PATH" if flashrom_present else "flashrom missing from PATH",
            "recommendation": "Install flashrom before attempting level 6 hardware recovery",
        }
    )
    checks.append(
        {
            "name": "Clean firmware baseline image",
            "status": "pass" if firmware_image_present else "fail",
            "severity": "warning",
            "detail": "drivers/G615LPAS.325 present" if firmware_image_present else "drivers/G615LPAS.325 is missing",
            "recommendation": "Add a known-good firmware image for secure write operations",
        }
    )
    checks.append(
        {
            "name": "NuclearBoot EFI payload",
            "status": "pass" if nuclear_boot_present else "fail",
            "severity": "warning",
            "detail": "NuclearBootEdk2.efi found in repo root" if nuclear_boot_present else "NuclearBootEdk2.efi missing in repo root",
            "recommendation": "Build/package PhoenixGuard artifacts before level 4+",
        }
    )

    level_readiness = {
        "level_1_detect": bool(uefi_mode and make_present),
        "level_2_soft": bool(uefi_mode and make_present and sudo_present),
        "level_3_secure": bool(uefi_mode and make_present and sudo_present and kexec_enabled and kexecctl_present and firmware_image_present),
        "level_4_vm": bool(uefi_mode and sudo_present and qemu_present and nuclear_boot_present),
        "level_5_xen": bool(uefi_mode and sudo_present and xen_present),
        "level_6_hardware": bool(uefi_mode and make_present and flashrom_present),
    }

    blocking_issues = [check["detail"] for check in checks if check["severity"] == "blocker" and check["status"] == "fail"]
    overall_status = "ready" if all(level_readiness.values()) else "degraded"

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "overall_status": overall_status,
        "blocking_issues": blocking_issues,
        "level_readiness": level_readiness,
        "checks": checks,
    }


def _print_text_report(report: Dict[str, object], summary_only: bool) -> None:
    print("PhoenixGuard Hardware Compatibility Probe")
    print("=" * 40)
    print(f"Overall status: {report['overall_status']}")
    print()

    print("Level readiness:")
    for level_name, ready in report["level_readiness"].items():
        marker = "READY" if ready else "MISSING PREREQUISITES"
        print(f"  - {level_name}: {marker}")

    if summary_only:
        return

    print()
    print("Detailed checks:")
    for check in report["checks"]:
        print(f"  - [{check['status'].upper()}] {check['name']}")
        print(f"    detail: {check['detail']}")
        print(f"    recommendation: {check['recommendation']}")

    if report["blocking_issues"]:
        print()
        print("Blocking issues:")
        for issue in report["blocking_issues"]:
            print(f"  - {issue}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe host compatibility for PhoenixGuard recovery levels")
    parser.add_argument("--format", choices=("text", "json"), default="text", help="Output format")
    parser.add_argument("--output", help="Optional file path to save report")
    parser.add_argument("--summary-only", action="store_true", help="Print/read level readiness summary only")
    args = parser.parse_args()

    report = run_probe()

    if args.format == "json":
        rendered = json.dumps(report, indent=2, sort_keys=True)
        if not args.summary_only:
            print(rendered)
        else:
            summary = {
                "overall_status": report["overall_status"],
                "blocking_issues": report["blocking_issues"],
                "level_readiness": report["level_readiness"],
            }
            print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        _print_text_report(report, args.summary_only)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
