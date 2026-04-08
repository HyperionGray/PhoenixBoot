#!/usr/bin/env bash
# Description: Scan repository for unfinished markers and summarize findings.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"
mkdir -p out/audit

MATCHES_FILE="$(mktemp)"
trap 'rm -f "${MATCHES_FILE}"' EXIT

if rg --line-number --no-heading --color never \
  -g '!out/**' \
  -g '!.git/**' \
  -g '!**/target/**' \
  -g '!**/node_modules/**' \
  -g '!**/*.min.js' \
  'TODO|STUB|FIXME|TBD|UNFINISHED|WIP|XXX' \
  . > "${MATCHES_FILE}"; then
  :
else
  if [ -s "${MATCHES_FILE}" ]; then
    echo "Unexpected scan error while generating unfinished audit" >&2
    exit 1
  fi
fi

python3 - "${MATCHES_FILE}" "out/audit/unfinished-report.json" "out/audit/unfinished-summary.txt" <<'PY'
import json
import sys
from collections import defaultdict
from pathlib import Path

matches_file = Path(sys.argv[1])
json_report = Path(sys.argv[2])
summary_report = Path(sys.argv[3])

entries = []
by_file = defaultdict(int)
by_marker = defaultdict(int)
markers = ("TODO", "STUB", "FIXME", "TBD", "UNFINISHED", "WIP", "XXX")

for raw in matches_file.read_text(encoding="utf-8").splitlines():
    # rg output format: path:line:content
    parts = raw.split(":", 2)
    if len(parts) != 3:
        continue

    file_path, line_number, content = parts
    marker = next((m for m in markers if m in content), "OTHER")

    entry = {
        "file": file_path,
        "line": int(line_number),
        "marker": marker,
        "content": content.strip(),
    }
    entries.append(entry)
    by_file[file_path] += 1
    by_marker[marker] += 1

sorted_files = sorted(by_file.items(), key=lambda kv: (-kv[1], kv[0]))
report = {
    "total_matches": len(entries),
    "by_marker": dict(sorted(by_marker.items())),
    "top_files": [{"file": f, "count": c} for f, c in sorted_files[:50]],
    "entries": entries[:500],
}

json_report.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8")

lines = [
    "PhoenixGuard Unfinished Marker Audit",
    "====================================",
    "",
    f"Total matches: {report['total_matches']}",
    "",
    "By marker:",
]

for marker, count in sorted(by_marker.items()):
    lines.append(f"  {marker}: {count}")

lines.extend(["", "Top files:"])
for item in report["top_files"][:20]:
    lines.append(f"  {item['count']:4d}  {item['file']}")

if not report["top_files"]:
    lines.append("  none")

lines.extend(
    [
        "",
        "Detailed JSON report: out/audit/unfinished-report.json",
        "Summary report: out/audit/unfinished-summary.txt",
    ]
)

summary_report.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

echo "Unfinished marker audit complete - see out/audit/unfinished-summary.txt"
