# Repository Hygiene Audit

PhoenixBoot includes a repository hygiene audit script to help keep the tree clean and avoid accidentally committing local runtime residue.

## What it checks

- File distribution across repository areas (`staging`, `dev`, `wip`, `demo`)
- Known stale runtime artifacts (for example root-level Podman lock/overlay residue)
- Unfinished code markers in active automation code (`TODO`, `STUB`, `FIXME`, `TBD`) within:
  - `scripts/`
  - `utils/`
  - `*.pf` task files

## Usage

Run from the repository root:

```bash
bash scripts/maintenance/audit-tree.sh
```

Optional modes:

```bash
# Remove known stale runtime artifacts if found
bash scripts/maintenance/audit-tree.sh --cleanup-stray

# Exit non-zero when stale files or unfinished markers exist
bash scripts/maintenance/audit-tree.sh --fail-on-findings
```

Or via task runner:

```bash
./pf.py maint-audit-tree
./pf.py maint-audit-tree-clean
./pf.py maint-audit-tree-strict
```

## Output

- Human-readable summary: `out/audit/summary.txt`
- Machine-readable report: `out/audit/report.json`
