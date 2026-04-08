# Maintenance Automation Update

## Summary

This update replaces a maintenance stub with real automation and adds a reusable
maintenance audit workflow aligned with the component-first repository layout.

## What changed

### New maintenance task: `maint-audit`

- Added task in `components/maint/maint.pf`
- Runs:
  1. Component layout validation (`scripts/testing/test-component-layout.sh`)
  2. Repository tree audit (`scripts/maintenance/audit-tree.sh`)
  3. Unfinished marker scan (`TODO|STUB|FIXME|TBD|XXX`)
- Writes report to:
  - `out/maintenance/maint-audit.txt`

### `maint-docs` now does real work

- Replaced previous placeholder implementation.
- New script: `scripts/maintenance/maint-docs.sh`
- Generates a maintenance health document at:
  - `out/maintenance/repo-health.md`
- Includes:
  - PF task-list availability and task count
  - `scripts/` compatibility entrypoint count
  - Count of files with unfinished markers in maintained paths

### Maintenance script reliability improvements

- Fixed repository-root detection in maintenance scripts so they work when
  invoked via compatibility symlinks under `scripts/`.
- Updated:
  - `scripts/maintenance/cleanup.sh`
  - `scripts/maintenance/audit-tree.sh`
  - `scripts/maintenance/lint.sh`
  - `scripts/maintenance/format.sh`

### Documentation updates

- Updated maintenance script README:
  - `components/maint/scripts/maintenance/README.md`
- Updated task catalog:
  - `docs/PF_TASKS.md`

## Why this matters

- Maintenance tasks are now actionable and verifiable instead of placeholder-only.
- Repository organization checks are now codified in a single task.
- Output is written to deterministic files under `out/maintenance/` for CI or
  local review.

## Usage

```bash
# Generate maintenance health docs
./pf.py maint-docs

# Run maintenance audit workflow
./pf.py maint-audit

# Clean generated maintenance output (plus other build artifacts)
./pf.py maint-clean
```
