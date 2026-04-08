#!/usr/bin/env python3
"""
PhoenixBoot development environment diagnostics.

Generates:
  - out/setup/doctor-report.txt
  - out/setup/doctor-report.json

This command is intentionally read-only and safe to run in CI/cloud VMs.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import List, Optional


@dataclass
class CheckResult:
    name: str
    status: str  # PASS, WARN, FAIL
    detail: str


REQUIRED_TOOLS = [
    "python3",
    "gcc",
    "openssl",
    "qemu-system-x86_64",
    "mcopy",
    "mkfs.fat",
    "parted",
    "sbsign",
    "mokutil",
    "cert-to-efi-sig-list",
    "sign-efi-sig-list",
]

OVMF_SEARCH_PATHS = [
    ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"),
    ("/usr/share/OVMF/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_VARS.fd"),
    ("/usr/share/ovmf/OVMF_CODE_4M.fd", "/usr/share/ovmf/OVMF_VARS_4M.fd"),
    ("/usr/share/ovmf/OVMF_CODE.fd", "/usr/share/ovmf/OVMF_VARS.fd"),
    ("/usr/share/edk2-ovmf/OVMF_CODE.fd", "/usr/share/edk2-ovmf/OVMF_VARS.fd"),
    ("/usr/share/qemu/OVMF_CODE.fd", "/usr/share/qemu/OVMF_VARS.fd"),
    ("/opt/ovmf/OVMF_CODE.fd", "/opt/ovmf/OVMF_VARS.fd"),
]


def check_tool(name: str) -> CheckResult:
    path = shutil.which(name)
    if path:
        return CheckResult(name=f"tool:{name}", status="PASS", detail=path)
    return CheckResult(name=f"tool:{name}", status="FAIL", detail="not found in PATH")


def check_pf_runner() -> CheckResult:
    path = shutil.which("pf")
    if path:
        return CheckResult(name="pf-runner", status="PASS", detail=path)
    return CheckResult(
        name="pf-runner",
        status="WARN",
        detail="pf not in PATH; ./pf.py tasks will fail until pf-runner is installed",
    )


def discover_ovmf() -> tuple[Optional[str], Optional[str]]:
    for code, vars_ in OVMF_SEARCH_PATHS:
        if os.path.isfile(code) and os.path.isfile(vars_):
            return code, vars_
    return None, None


def check_ovmf() -> CheckResult:
    code, vars_ = discover_ovmf()
    if code and vars_:
        return CheckResult(name="ovmf", status="PASS", detail=f"CODE={code} VARS={vars_}")
    return CheckResult(name="ovmf", status="FAIL", detail="OVMF CODE/VARS files not found")


def check_kvm() -> CheckResult:
    kvm = Path("/dev/kvm")
    if not kvm.exists():
        return CheckResult(
            name="kvm",
            status="WARN",
            detail="/dev/kvm not present; QEMU should use '-cpu max' without -enable-kvm",
        )

    readable = os.access(kvm, os.R_OK)
    writable = os.access(kvm, os.W_OK)
    if readable and writable:
        return CheckResult(name="kvm", status="PASS", detail="/dev/kvm is accessible")
    return CheckResult(
        name="kvm",
        status="WARN",
        detail="/dev/kvm exists but is not fully accessible; fallback to TCG recommended",
    )


def check_path_local_bin() -> CheckResult:
    path = os.environ.get("PATH", "")
    if os.path.expanduser("~/.local/bin") in path.split(":"):
        return CheckResult(name="path:~/.local/bin", status="PASS", detail="present in PATH")
    return CheckResult(
        name="path:~/.local/bin",
        status="WARN",
        detail="missing from PATH; pf installed in ~/.local/bin may not be found",
    )


def write_reports(results: List[CheckResult], strict: bool) -> int:
    out_dir = Path("out/setup")
    out_dir.mkdir(parents=True, exist_ok=True)

    code, vars_ = discover_ovmf()
    if code and vars_:
        (out_dir / "ovmf_code_path").write_text(code + "\n", encoding="utf-8")
        (out_dir / "ovmf_vars_path").write_text(vars_ + "\n", encoding="utf-8")

    failures = sum(1 for r in results if r.status == "FAIL")
    warnings = sum(1 for r in results if r.status == "WARN")

    payload = {
        "summary": {
            "failures": failures,
            "warnings": warnings,
            "strict": strict,
            "ok": failures == 0 and (warnings == 0 if strict else True),
        },
        "checks": [asdict(r) for r in results],
    }
    (out_dir / "doctor-report.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    lines = [
        "PhoenixBoot Development Environment Doctor",
        "=========================================",
        "",
        f"Failures: {failures}",
        f"Warnings: {warnings}",
        f"Strict mode: {'yes' if strict else 'no'}",
        "",
    ]
    for r in results:
        lines.append(f"[{r.status}] {r.name}: {r.detail}")
    lines.append("")
    lines.append("JSON report: out/setup/doctor-report.json")
    lines.append("Text report: out/setup/doctor-report.txt")
    (out_dir / "doctor-report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    for line in lines:
        print(line)

    if failures > 0:
        return 1
    if strict and warnings > 0:
        return 2
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run PhoenixBoot environment diagnostics")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as non-zero exit status",
    )
    args = parser.parse_args()

    results: List[CheckResult] = []
    results.extend(check_tool(name) for name in REQUIRED_TOOLS)
    results.append(check_pf_runner())
    results.append(check_path_local_bin())
    results.append(check_ovmf())
    results.append(check_kvm())

    return write_reports(results, strict=args.strict)


if __name__ == "__main__":
    sys.exit(main())
