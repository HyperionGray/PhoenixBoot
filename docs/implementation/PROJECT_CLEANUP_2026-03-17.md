# Project Cleanup - 2026-03-17

This cleanup pass removed stale generated artifacts and backup-only content to
keep the repository smaller and easier to navigate.

## Removed

- `examples_and_samples/demo/legacy/bak/`
  - Legacy backup tree with old test outputs, logs, qcow2 images, and archived
    demo scripts.
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/`
  - Generated Rust build and rustdoc artifacts.
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/debug.log`
  - Stray runtime log file.
- `examples_and_samples/demo/makefile/Makefile.old`
  - Obsolete backup makefile.

## Repo hygiene guards added

Updated `.gitignore` to prevent reintroducing these artifacts:

- `examples_and_samples/demo/legacy/bak/`
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/`
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/debug.log`
- `examples_and_samples/demo/makefile/Makefile.old`

## If you need the Rust demo outputs again

From `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/`:

```bash
cargo build
cargo doc --no-deps
```
