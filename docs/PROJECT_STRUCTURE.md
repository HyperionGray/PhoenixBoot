# PhoenixBoot Project Structure

PhoenixBoot is now organized by component while preserving the legacy root entrypoints used by scripts, containers, and documentation.

## Top-level layout

- `components/` - Component-first task and script ownership
- `includes/` - Shared shell includes and per-component include namespaces
- `scripts/` - Compatibility symlinks that preserve existing `scripts/...` paths
- `staging/` - Production EFI sources, headers, binaries, and tooling
- `containers/` - Container build, test, installer, runtime, and TUI environments
- `tests/` - Repository-level test helpers
- `Pfyfile.pf` - Main PF entrypoint
- `core.pf`, `secure.pf`, `workflows.pf`, `maint.pf` - Compatibility wrappers that forward to `components/`

## Component layout

Each main component now follows the same high-level shape:

```text
components/<name>/
├── include/
├── src/
├── build/
├── bin/
├── scripts/
├── Makefile
└── Pfyfile.pf
```

Current components:

- `components/core/` - Core PF tasks plus build, testing, validation, and UEFI tooling scripts
- `components/secure/` - Secure Boot and MOK management tasks and scripts
- `components/workflows/` - ESP packaging, QEMU helper, recovery, and USB workflow scripts
- `components/maint/` - Maintenance tasks, git hooks, release helpers, and templates

## Compatibility model

- Continue using `./pf.py <task>` from the repository root
- Continue using `scripts/...` paths if you already have automation built around them
- Shared shell helpers now live in `includes/lib/`, with `scripts/lib/` retained as a compatibility symlink

## Notes

- `components/core/src`, `components/core/include`, and `components/core/bin` point at the existing `staging/` production content
- Component `build/` directories are placeholders for local/generated build output and are not used for committed artifacts
- Use the top-level `Makefile` unless you have a component-specific reason to invoke a nested one
