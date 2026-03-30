#!/usr/bin/env python3
"""
PhoenixBoot hardware compatibility probe.

This utility checks whether the current host has the capabilities and tools
required for common PhoenixBoot workflows and writes a JSON report.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(cmd: List[str], timeout: int = 5) -> Tuple[int, str, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()
    except Exception as exc:  # pragma: no cover - defensive path
        return 1, "", str(exc)


def cmd_exists(name: str) -> bool:
    return shutil.which(name) is not None


def parse_mokutil_state(output: str) -> str:
    lowered = output.lower()
    if "secureboot enabled" in lowered:
        return "enabled"
    if "secureboot disabled" in lowered:
        return "disabled"
    return "unknown"


def first_path(patterns: List[Path]) -> Optional[str]:
    for p in patterns:
        if p.exists():
            return str(p)
    return None


@dataclass
class Requirement:
    name: str
    required: bool
    present: bool
    note: str = ""


def score_requirements(items: List[Requirement]) -> Dict[str, int]:
    required_total = sum(1 for i in items if i.required)
    required_ok = sum(1 for i in items if i.required and i.present)
    optional_total = sum(1 for i in items if not i.required)
    optional_ok = sum(1 for i in items if (not i.required) and i.present)
    return {
        "required_total": required_total,
        "required_ok": required_ok,
        "optional_total": optional_total,
        "optional_ok": optional_ok,
    }


def compatibility_label(required_ok: int, required_total: int) -> str:
    if required_total == 0:
        return "READY"
    ratio = required_ok / required_total
    if ratio == 1.0:
        return "READY"
    if ratio >= 0.7:
        return "PARTIAL"
    return "BLOCKED"


def build_report() -> Dict[str, object]:
    is_root = os.geteuid() == 0
    uefi_mode = Path("/sys/firmware/efi").exists()
    efivars_path = Path("/sys/firmware/efi/efivars")
    efivars_accessible = efivars_path.exists() and os.access(efivars_path, os.R_OK)

    mokutil_state = "unknown"
    mokutil_raw = ""
    if cmd_exists("mokutil"):
        rc, out, err = run_command(["mokutil", "--sb-state"])
        mokutil_raw = out if out else err
        if rc == 0:
            mokutil_state = parse_mokutil_state(out)

    ovmf_candidates = [
        Path("/usr/share/OVMF/OVMF_CODE.fd"),
        Path("/usr/share/OVMF/OVMF_CODE_4M.fd"),
        Path("/usr/share/edk2/ovmf/OVMF_CODE.fd"),
        Path("/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"),
    ]
    ovmf_code_path = first_path(ovmf_candidates)

    chipsec_present = False
    rc, _, _ = run_command(
        [sys.executable, "-c", "import chipsec_main"], timeout=4
    )
    if rc == 0:
        chipsec_present = True

    core = [
        Requirement("python3", True, cmd_exists("python3")),
        Requirement("bash", True, cmd_exists("bash")),
        Requirement("openssl", True, cmd_exists("openssl")),
        Requirement("efibootmgr", True, cmd_exists("efibootmgr")),
        Requirement("mokutil", True, cmd_exists("mokutil")),
        Requirement("sbsign", False, cmd_exists("sbsign")),
        Requirement("sbverify", False, cmd_exists("sbverify")),
    ]
    build = [
        Requirement("gcc", True, cmd_exists("gcc")),
        Requirement("make", True, cmd_exists("make")),
        Requirement("qemu-system-x86_64", False, cmd_exists("qemu-system-x86_64")),
        Requirement("mcopy", False, cmd_exists("mcopy")),
        Requirement("mkfs.vfat", False, cmd_exists("mkfs.vfat")),
    ]
    firmware = [
        Requirement("dmidecode", True, cmd_exists("dmidecode")),
        Requirement("flashrom", False, cmd_exists("flashrom")),
        Requirement("chipsec python module", False, chipsec_present),
    ]

    sections = {
        "core_secure_boot": core,
        "build_and_test": build,
        "firmware_recovery": firmware,
    }

    section_scores: Dict[str, Dict[str, int]] = {}
    section_labels: Dict[str, str] = {}
    for section, reqs in sections.items():
        score = score_requirements(reqs)
        section_scores[section] = score
        section_labels[section] = compatibility_label(
            score["required_ok"], score["required_total"]
        )

    all_required_total = sum(v["required_total"] for v in section_scores.values())
    all_required_ok = sum(v["required_ok"] for v in section_scores.values())

    findings: List[str] = []
    if not uefi_mode:
        findings.append("System is not booted in UEFI mode.")
    if not efivars_accessible:
        findings.append("EFI variables are not accessible for read operations.")
    if mokutil_state == "disabled":
        findings.append("Secure Boot is disabled.")
    if not is_root:
        findings.append("Running as non-root; firmware checks are limited.")
    if ovmf_code_path is None:
        findings.append("OVMF firmware was not found; QEMU UEFI tests may fail.")

    next_steps: List[str] = []
    if not cmd_exists("efibootmgr"):
        next_steps.append("Install efibootmgr for UEFI boot entry management.")
    if not cmd_exists("mokutil"):
        next_steps.append("Install mokutil to verify/enroll Secure Boot keys.")
    if not cmd_exists("dmidecode"):
        next_steps.append("Install dmidecode for hardware inventory checks.")
    if not cmd_exists("qemu-system-x86_64"):
        next_steps.append("Install qemu-system-x86_64 for virtualization tests.")
    if ovmf_code_path is None:
        next_steps.append("Install OVMF firmware package for UEFI VM tests.")

    overall = compatibility_label(all_required_ok, all_required_total)

    return {
        "metadata": {
            "generated_at_utc": utc_now_iso(),
            "hostname": socket.gethostname(),
            "platform": platform.platform(),
            "kernel": platform.release(),
            "python": sys.version.split()[0],
        },
        "system_state": {
            "is_root": is_root,
            "uefi_mode": uefi_mode,
            "efivars_accessible": efivars_accessible,
            "secure_boot_state": mokutil_state,
            "secure_boot_raw": mokutil_raw,
            "ovmf_code_path": ovmf_code_path,
        },
        "compatibility": {
            "overall": overall,
            "required_ok": all_required_ok,
            "required_total": all_required_total,
            "sections": {
                k: {
                    "label": section_labels[k],
                    "score": section_scores[k],
                    "requirements": [
                        {
                            "name": r.name,
                            "required": r.required,
                            "present": r.present,
                            "note": r.note,
                        }
                        for r in v
                    ],
                }
                for k, v in sections.items()
            },
        },
        "findings": findings,
        "next_steps": next_steps,
    }


def print_summary(report: Dict[str, object]) -> None:
    comp = report["compatibility"]
    system = report["system_state"]
    print("PhoenixBoot Hardware Compatibility Probe")
    print("=" * 40)
    print(f"Overall: {comp['overall']}")
    print(f"Required checks: {comp['required_ok']}/{comp['required_total']}")
    print(f"UEFI mode: {system['uefi_mode']}")
    print(f"Secure Boot: {system['secure_boot_state']}")
    print("")

    sections = comp["sections"]
    for name, section in sections.items():
        score = section["score"]
        print(
            f"- {name}: {section['label']} "
            f"(required {score['required_ok']}/{score['required_total']}, "
            f"optional {score['optional_ok']}/{score['optional_total']})"
        )

    findings = report["findings"]
    if findings:
        print("\nFindings:")
        for item in findings:
            print(f"  - {item}")

    next_steps = report["next_steps"]
    if next_steps:
        print("\nRecommended actions:")
        for item in next_steps:
            print(f"  - {item}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Probe host hardware/software compatibility for PhoenixBoot."
    )
    parser.add_argument(
        "--output",
        default="out/reports/hardware_compatibility_report.json",
        help="Path to JSON output report",
    )
    parser.add_argument(
        "--json-only",
        action="store_true",
        help="Print only JSON to stdout (still writes output file)",
    )
    args = parser.parse_args()

    report = build_report()

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    if args.json_only:
        print(json.dumps(report, indent=2))
    else:
        print_summary(report)
        print(f"\nReport written: {output_path}")

    if report["compatibility"]["overall"] == "BLOCKED":
        return 2
    if report["compatibility"]["overall"] == "PARTIAL":
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
