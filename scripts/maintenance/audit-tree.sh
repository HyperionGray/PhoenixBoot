#!/usr/bin/env bash
# Description: Audits repository structure and categorizes tracked files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"
mkdir -p out/audit

FILE_LIST="$(mktemp)"
trap 'rm -f "${FILE_LIST}"' EXIT

rg --files . \
  -g '!out/**' \
  -g '!.git/**' \
  -g '!examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/**' \
  > "${FILE_LIST}"

python3 - "${FILE_LIST}" "out/audit/report.json" "out/audit/summary.txt" <<'PY'
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

file_list_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
summary_path = Path(sys.argv[3])

categories = defaultdict(list)

demo_re = re.compile(r"(demo|example|sample|sandbox|mock|/bak/|test-)", re.IGNORECASE)
wip_re = re.compile(r"(wip|proto|experimental|universal_bios|universal-bios)", re.IGNORECASE)
dev_re = re.compile(r"(bringup|platform|board|hardware_|flashrom|bootstrap)", re.IGNORECASE)

with file_list_path.open("r", encoding="utf-8") as fh:
    for raw in fh:
        file_path = raw.strip()
        if not file_path:
            continue

        if demo_re.search(file_path):
            categories["demo"].append(file_path)
        elif wip_re.search(file_path):
            categories["wip"].append(file_path)
        elif dev_re.search(file_path):
            categories["dev"].append(file_path)
        else:
            categories["staging"].append(file_path)

report = {
    "counts": {
        "staging": len(categories["staging"]),
        "dev": len(categories["dev"]),
        "wip": len(categories["wip"]),
        "demo": len(categories["demo"]),
        "total": sum(len(v) for v in categories.values()),
    },
    "samples": {
        name: entries[:20] for name, entries in categories.items()
    },
}

report_path.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")

lines = [
    "PhoenixGuard Repository Audit Summary",
    "===================================",
    "",
    f"STAGING: {report['counts']['staging']} files",
    f"DEV: {report['counts']['dev']} files",
    f"WIP: {report['counts']['wip']} files",
    f"DEMO: {report['counts']['demo']} files",
    f"TOTAL: {report['counts']['total']} files",
    "",
    "JSON report: out/audit/report.json",
]

summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

echo "Audit complete - see out/audit/"

