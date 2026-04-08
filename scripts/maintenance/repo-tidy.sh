#!/usr/bin/env bash
# Scan for common stray/generated files and optionally remove them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${PROJECT_ROOT}"

APPLY="${APPLY:-0}"

if [ "${APPLY}" = "1" ]; then
  echo "repo-tidy: apply mode (files will be removed)"
else
  echo "repo-tidy: dry-run mode (set APPLY=1 to remove files)"
fi

python3 - <<'PY'
import os
import shutil
from pathlib import Path

apply = os.environ.get("APPLY", "0") == "1"
root = Path(".").resolve()

dir_names = {"__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".cache"}
file_suffixes = {".pyc", ".pyo", ".tmp"}
file_names = {".DS_Store", "Thumbs.db", ".coverage"}

dirs = set()
files = set()

for current_root, subdirs, current_files in os.walk(root):
    cur_path = Path(current_root)
    if ".git" in cur_path.parts:
        continue

    for dirname in list(subdirs):
        if dirname in dir_names:
            dirs.add(cur_path / dirname)

    for filename in current_files:
        p = cur_path / filename
        if (
            filename in file_names
            or p.suffix in file_suffixes
            or filename.endswith("~")
        ):
            files.add(p)

dirs_sorted = sorted(dirs)
files_sorted = sorted(files)

if not dirs_sorted and not files_sorted:
    print("repo-tidy: nothing to clean")
    raise SystemExit(0)

print(f"repo-tidy: found {len(dirs_sorted)} directories and {len(files_sorted)} files")

if dirs_sorted:
    print("directories:")
    for d in dirs_sorted:
        print(f"  {d.relative_to(root)}")

if files_sorted:
    print("files:")
    for f in files_sorted:
        print(f"  {f.relative_to(root)}")

if not apply:
    print("repo-tidy: dry-run complete")
    raise SystemExit(0)

for d in dirs_sorted:
    shutil.rmtree(d, ignore_errors=True)

for f in files_sorted:
    try:
        f.unlink()
    except FileNotFoundError:
        pass

print("repo-tidy: cleanup complete")
PY
