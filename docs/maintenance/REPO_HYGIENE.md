# Repository Hygiene

This repository includes a maintenance helper that checks for and optionally removes
tracked generated artifacts and other stale files that should not live in git history.

## Why this exists

Over time, generated outputs can accidentally get committed (for example Rust `target/`
build directories or debug logs). These files:

- increase repository size,
- add noisy diffs,
- slow down code review and automation.

The hygiene script gives a repeatable way to detect and clean those artifacts.

## Script

`scripts/maintenance/repo-hygiene.sh`

### Modes

- Check mode (default):

  ```bash
  bash scripts/maintenance/repo-hygiene.sh
  ```

- Apply mode (removes tracked artifacts from the git index):

  ```bash
  APPLY=1 bash scripts/maintenance/repo-hygiene.sh
  ```

Apply mode uses `git rm -r` for known generated paths.

## pf tasks

From `maint.pf`:

- `maint-repo-hygiene-check` - run in check mode
- `maint-repo-hygiene-fix` - run in apply mode

Examples:

```bash
./pf.py maint-repo-hygiene-check
./pf.py maint-repo-hygiene-fix
```

## Current cleanup targets

- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/`
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/debug.log`

Add new targets carefully and only for files/directories that are generated artifacts.
