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
- `repo-tidy.sh` - Remove stale/generated clutter (supports dry-run)
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

# Preview repository cleanup actions
DRY_RUN=1 ./scripts/maintenance/repo-tidy.sh

# Apply repository cleanup actions
APPLY=1 ./scripts/maintenance/repo-tidy.sh
```
