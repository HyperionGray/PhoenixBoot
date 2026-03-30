#!/usr/bin/env python3
"""Validate repository hygiene for .github/workflows files."""

from __future__ import annotations

import re
import sys
from pathlib import Path

WORKFLOWS_DIR = Path(".github/workflows")
ALLOWED_EXTENSIONS = {".yml", ".yaml"}
BACKUP_NAME_PATTERN = re.compile(r"(backup|template)", re.IGNORECASE)
PLACEHOLDER_PATTERN = re.compile(r"^\s*#\s*placeholder workflow", re.IGNORECASE | re.MULTILINE)
ON_KEY_PATTERN = re.compile(r"^\s*(?:on|['\"]on['\"])\s*:", re.MULTILINE)
NAME_KEY_PATTERN = re.compile(r"^\s*name\s*:", re.MULTILINE)


def main() -> int:
    violations: list[str] = []

    if not WORKFLOWS_DIR.exists() or not WORKFLOWS_DIR.is_dir():
        print(f"ERROR: directory not found: {WORKFLOWS_DIR}")
        return 1

    workflow_files: list[Path] = []

    for entry in sorted(WORKFLOWS_DIR.iterdir(), key=lambda p: p.name.lower()):
        if entry.is_dir():
            continue

        if entry.name.startswith("."):
            violations.append(
                f"hidden file in workflows directory is not allowed: {entry.as_posix()}"
            )
            continue

        if entry.suffix.lower() not in ALLOWED_EXTENSIONS:
            violations.append(
                f"non-workflow file extension in workflows directory: {entry.as_posix()}"
            )
            continue

        if BACKUP_NAME_PATTERN.search(entry.name):
            violations.append(
                f"backup/template workflow file detected: {entry.as_posix()}"
            )

        workflow_files.append(entry)

    stem_to_files: dict[str, list[Path]] = {}
    for workflow_file in workflow_files:
        stem_to_files.setdefault(workflow_file.stem.lower(), []).append(workflow_file)

    for stem, files in sorted(stem_to_files.items()):
        if len(files) > 1:
            names = ", ".join(file.name for file in files)
            violations.append(
                f"duplicate workflow basenames found for '{stem}': {names}. "
                "Keep a single canonical file."
            )

    for workflow_file in workflow_files:
        content = workflow_file.read_text(encoding="utf-8", errors="replace")
        non_empty_lines = [line for line in content.splitlines() if line.strip()]

        if len(non_empty_lines) < 3:
            violations.append(
                f"workflow file is suspiciously short: {workflow_file.as_posix()}"
            )

        if PLACEHOLDER_PATTERN.search(content):
            violations.append(
                f"placeholder marker found in workflow file: {workflow_file.as_posix()}"
            )

        if not NAME_KEY_PATTERN.search(content):
            violations.append(
                f"missing top-level 'name' key in: {workflow_file.as_posix()}"
            )

        if not ON_KEY_PATTERN.search(content):
            violations.append(
                f"missing top-level 'on' key in: {workflow_file.as_posix()}"
            )

    if violations:
        print("Workflow hygiene validation failed:")
        for violation in violations:
            print(f" - {violation}")
        return 1

    print(
        f"Workflow hygiene validation passed for {len(workflow_files)} workflow files "
        f"in {WORKFLOWS_DIR.as_posix()}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
