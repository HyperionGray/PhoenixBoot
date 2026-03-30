#!/usr/bin/env python3
"""
Generate a repository progress and cleanup report.

This report is intended for routine maintenance automation and includes:
- Recent commit trend
- Actionable unfinished markers (TODO/FIXME/STUB/...)
- Tracked stray/generated artifact candidates
- Deep directory nesting hotspots
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Sequence


MARKER_RE = re.compile(r"\b(TODO|FIXME|STUB|TBD|XXX|WIP|UNFINISHED)\b")

DEFAULT_EXCLUDED_PREFIXES = (
    "examples_and_samples/demo/legacy-old/",
    "examples_and_samples/demo/legacy/",
)


@dataclass
class MarkerHit:
    file: str
    line: int
    marker: str
    text: str


def run(cmd: Sequence[str], cwd: Path) -> str:
    result = subprocess.run(
        list(cmd),
        cwd=str(cwd),
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


def git_ls_files(repo_root: Path) -> list[str]:
    raw = run(["git", "ls-files", "-z"], cwd=repo_root)
    return [p for p in raw.split("\0") if p]


def collect_commits(repo_root: Path, limit: int) -> list[dict[str, str]]:
    out = run(
        [
            "git",
            "log",
            f"-n{limit}",
            "--date=short",
            "--pretty=format:%h%x09%ad%x09%s",
        ],
        cwd=repo_root,
    )
    commits = []
    for line in out.splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3:
            commits.append({"sha": parts[0], "date": parts[1], "subject": parts[2]})
    return commits


def collect_recent_touched_paths(repo_root: Path, limit: int) -> Counter[str]:
    out = run(["git", "log", f"-n{limit}", "--name-only", "--pretty=format:"], cwd=repo_root)
    counter: Counter[str] = Counter()
    for line in out.splitlines():
        path = line.strip()
        if not path:
            continue
        top = path.split("/", 1)[0]
        counter[top] += 1
    return counter


def is_excluded(path: str, excluded_prefixes: Iterable[str]) -> bool:
    return any(path.startswith(prefix) for prefix in excluded_prefixes)


def collect_markers(
    repo_root: Path,
    tracked_files: Sequence[str],
    excluded_prefixes: Sequence[str],
    max_hits: int,
    max_file_bytes: int,
) -> tuple[Counter[str], list[MarkerHit], Counter[str]]:
    marker_counts: Counter[str] = Counter()
    by_top_dir: Counter[str] = Counter()
    hits: list[MarkerHit] = []

    text_suffixes = {
        ".py",
        ".sh",
        ".md",
        ".txt",
        ".yml",
        ".yaml",
        ".json",
        ".json5",
        ".toml",
        ".ini",
        ".cfg",
        ".conf",
        ".c",
        ".h",
        ".cpp",
        ".hpp",
        ".rs",
        ".go",
        ".java",
        ".js",
        ".ts",
        ".tsx",
        ".pf",
    }

    for rel_path in tracked_files:
        if is_excluded(rel_path, excluded_prefixes):
            continue
        path = repo_root / rel_path
        if not path.is_file():
            continue
        if path.suffix.lower() not in text_suffixes:
            continue
        if path.stat().st_size > max_file_bytes:
            continue
        try:
            with path.open("r", encoding="utf-8", errors="ignore") as handle:
                for idx, line in enumerate(handle, 1):
                    for match in MARKER_RE.finditer(line):
                        marker = match.group(1)
                        marker_counts[marker] += 1
                        by_top_dir[rel_path.split("/", 1)[0]] += 1
                        if len(hits) < max_hits:
                            hits.append(
                                MarkerHit(
                                    file=rel_path,
                                    line=idx,
                                    marker=marker,
                                    text=line.strip(),
                                )
                            )
        except OSError:
            continue
    return marker_counts, hits, by_top_dir


def collect_stray_candidates(tracked_files: Sequence[str]) -> dict[str, list[str]]:
    categories: dict[str, list[str]] = defaultdict(list)
    for rel_path in tracked_files:
        lowered = rel_path.lower()
        name = Path(rel_path).name
        if "/target/" in rel_path:
            categories["rust_target_artifacts"].append(rel_path)
        if "__pycache__/" in rel_path or lowered.endswith(".pyc"):
            categories["python_cache_artifacts"].append(rel_path)
        if lowered.endswith((".swp", ".swo")) or name.endswith("~"):
            categories["editor_temp_artifacts"].append(rel_path)
        if name in {".DS_Store", "nohup.out"} or name.startswith("nohup"):
            categories["process_or_platform_leftovers"].append(rel_path)
        if "/bak/" in rel_path:
            categories["backup_directory_content"].append(rel_path)
    return dict(categories)


def collect_depth_hotspots(tracked_files: Sequence[str], min_depth: int, limit: int) -> list[dict[str, int | str]]:
    depth_map = []
    for path in tracked_files:
        depth = path.count("/")
        if depth >= min_depth:
            depth_map.append({"path": path, "depth": depth})
    depth_map.sort(key=lambda item: item["depth"], reverse=True)
    return depth_map[:limit]


def build_recommendations(
    touched_top_dirs: Counter[str],
    marker_total: int,
    stray_candidates: dict[str, list[str]],
    depth_hotspots: list[dict[str, int | str]],
) -> list[str]:
    recommendations: list[str] = []

    top_recent = [name for name, _ in touched_top_dirs.most_common(3)]
    if ".github" in top_recent:
        recommendations.append(
            "Recent activity trends toward CI/automation; prioritize small, testable maintenance improvements."
        )

    if marker_total > 0:
        recommendations.append(
            "Schedule marker burn-down by active area, starting with scripts and utils before legacy/demo paths."
        )

    stray_count = sum(len(v) for v in stray_candidates.values())
    if stray_count > 0:
        recommendations.append(
            "Clean tracked generated artifacts and add/verify ignore rules so these files do not re-enter the tree."
        )

    if depth_hotspots:
        recommendations.append(
            "Review deeply nested paths and flatten where practical to improve maintainability."
        )

    if not recommendations:
        recommendations.append("No urgent hygiene findings detected; continue incremental feature work.")

    return recommendations


def write_json(output_json: Path, payload: dict) -> None:
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def write_markdown(output_md: Path, payload: dict) -> None:
    output_md.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []
    lines.append("# Repository Progress and Cleanup Report")
    lines.append("")
    lines.append(f"- Generated: {payload['generated_at_utc']}")
    lines.append(f"- Branch: `{payload['git']['branch']}`")
    lines.append("")

    lines.append("## Recent Commit Direction")
    lines.append("")
    for commit in payload["git"]["recent_commits"]:
        lines.append(f"- `{commit['sha']}` ({commit['date']}): {commit['subject']}")
    lines.append("")
    lines.append("Most touched top-level paths (recent window):")
    lines.append("")
    for key, value in payload["git"]["touched_top_dirs"]:
        lines.append(f"- `{key}`: {value}")
    lines.append("")

    lines.append("## Unfinished Marker Summary")
    lines.append("")
    marker_total = payload["unfinished_markers"]["total"]
    lines.append(f"- Total markers: **{marker_total}**")
    lines.append("- Marker counts:")
    for key, value in payload["unfinished_markers"]["counts"].items():
        lines.append(f"  - `{key}`: {value}")
    lines.append("")
    lines.append("Top directories with markers:")
    for key, value in payload["unfinished_markers"]["top_dirs"]:
        lines.append(f"- `{key}`: {value}")
    lines.append("")
    lines.append("Sample marker hits:")
    for item in payload["unfinished_markers"]["sample_hits"]:
        lines.append(f"- `{item['file']}:{item['line']}` `{item['marker']}` - {item['text']}")
    lines.append("")

    lines.append("## Tracked Stray/Generated Artifact Candidates")
    lines.append("")
    if not payload["cleanup_candidates"]:
        lines.append("- None detected in tracked files.")
    else:
        for category, files in payload["cleanup_candidates"].items():
            lines.append(f"- `{category}`: {len(files)}")
    lines.append("")

    lines.append("## Deep Directory Hotspots")
    lines.append("")
    if payload["depth_hotspots"]:
        for item in payload["depth_hotspots"]:
            lines.append(f"- depth {item['depth']}: `{item['path']}`")
    else:
        lines.append("- None above configured threshold.")
    lines.append("")

    lines.append("## Suggested Next Steps")
    lines.append("")
    for rec in payload["recommendations"]:
        lines.append(f"- {rec}")
    lines.append("")

    output_md.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate repository progress and cleanup report.")
    parser.add_argument("--repo-root", default=".", help="Repository root directory")
    parser.add_argument("--max-commits", type=int, default=12, help="How many recent commits to analyze")
    parser.add_argument("--max-marker-hits", type=int, default=80, help="Sample marker hits to store")
    parser.add_argument("--max-file-bytes", type=int, default=2_000_000, help="Max file size scanned for markers")
    parser.add_argument("--min-depth", type=int, default=8, help="Minimum path depth considered a hotspot")
    parser.add_argument("--depth-limit", type=int, default=25, help="Max number of depth hotspots in report")
    parser.add_argument(
        "--exclude-prefix",
        action="append",
        default=list(DEFAULT_EXCLUDED_PREFIXES),
        help="Path prefix to exclude from marker scanning (repeatable)",
    )
    parser.add_argument("--json-out", default="out/reports/repo_progress_report.json")
    parser.add_argument("--md-out", default="out/reports/repo_progress_report.md")
    parser.add_argument("--fail-on-stray", action="store_true", help="Exit non-zero when stray candidates exist")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    try:
        branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo_root).strip()
        tracked_files = git_ls_files(repo_root)
        commits = collect_commits(repo_root, args.max_commits)
        touched = collect_recent_touched_paths(repo_root, args.max_commits)
        marker_counts, marker_hits, marker_dirs = collect_markers(
            repo_root=repo_root,
            tracked_files=tracked_files,
            excluded_prefixes=args.exclude_prefix,
            max_hits=args.max_marker_hits,
            max_file_bytes=args.max_file_bytes,
        )
        stray = collect_stray_candidates(tracked_files)
        depth_hotspots = collect_depth_hotspots(tracked_files, args.min_depth, args.depth_limit)
        recommendations = build_recommendations(
            touched_top_dirs=touched,
            marker_total=sum(marker_counts.values()),
            stray_candidates=stray,
            depth_hotspots=depth_hotspots,
        )
    except subprocess.CalledProcessError as err:
        print(f"error: failed to gather git data: {err}", file=sys.stderr)
        return 2

    payload = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "git": {
            "branch": branch,
            "recent_commits": commits,
            "touched_top_dirs": touched.most_common(10),
        },
        "unfinished_markers": {
            "total": sum(marker_counts.values()),
            "counts": dict(marker_counts),
            "top_dirs": marker_dirs.most_common(10),
            "sample_hits": [
                {"file": h.file, "line": h.line, "marker": h.marker, "text": h.text}
                for h in marker_hits
            ],
        },
        "cleanup_candidates": stray,
        "depth_hotspots": depth_hotspots,
        "recommendations": recommendations,
    }

    json_path = (repo_root / args.json_out).resolve()
    md_path = (repo_root / args.md_out).resolve()
    write_json(json_path, payload)
    write_markdown(md_path, payload)

    stray_count = sum(len(files) for files in stray.values())
    print(f"wrote {json_path}")
    print(f"wrote {md_path}")
    print(
        f"summary: markers={payload['unfinished_markers']['total']} "
        f"stray_candidates={stray_count} depth_hotspots={len(depth_hotspots)}"
    )

    if args.fail_on_stray and stray_count > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
