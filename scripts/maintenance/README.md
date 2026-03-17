# Maintenance Scripts

Scripts for project maintenance and development.

## Code Quality

- `format.sh` - Format code
- `lint.sh` - Lint code

## Environment Setup

- `toolchain-check.sh` - Check build toolchain
- `init-structure.sh` - Initialize project structure

## Project Organization

- `move-boot-dev.sh` - Move boot to development
- `move-demo.sh` - Move demo files
- `move-prod-staging.sh` - Move to production staging
- `move-wip.sh` - Move work in progress
- `audit-tree.sh` - Audit repository hygiene, unfinished markers, and runtime artifacts
- `purge-demo-refs.sh` - Purge demo references
- `os-boot-clean.sh` - Clean boot entries

## Documentation

- `regen-instructions.sh` - Regenerate instructions

## Usage

```bash
# Lint code
./scripts/maintenance/lint.sh

# Format code
./scripts/maintenance/format.sh

# Check toolchain
./scripts/maintenance/toolchain-check.sh

# Run repository hygiene audit
./scripts/maintenance/audit-tree.sh
```

## Audit Output

`audit-tree.sh` generates:

- `out/audit/summary.txt` - Human-readable audit summary
- `out/audit/report.json` - Structured report for automation

The audit currently reports:

- Tracked file distribution by category (`staging`, `dev`, `wip`, `demo`, `other`)
- Unfinished markers (`TODO`, `FIXME`, `STUB`, etc.) in operational code paths
- Known runtime artifact files that are present and whether they are still tracked
