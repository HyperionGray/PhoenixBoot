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
- `audit-tree.sh` - Audit project tree
- `purge-demo-refs.sh` - Purge demo references
- `os-boot-clean.sh` - Clean boot entries

### Audit Outputs

`audit-tree.sh` generates reports in `out/audit/`:

- `summary.txt` - high-level totals and report pointers
- `classification.txt` - tracked file classification counts
- `unfinished-markers.txt` - TODO/FIXME/STUB/TBD/WIP markers
- `stale-paths.txt` - potentially stale/generated tracked paths
- `report.json` - machine-readable summary for automation

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
```
