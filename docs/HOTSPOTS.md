# PhoenixBoot Development Hotspots

This file tracks areas of active development or areas needing attention.

## Current Hotspots (2026-01-30)

### High Priority

~~**Container Architecture** - Actively being refined~~
~~Location: `containers/`~~
~~Status: Production-ready but evolving~~
~~See: [docs/CONTAINER_ARCHITECTURE.md](docs/CONTAINER_ARCHITECTURE.md)~~

   UPDATE: This path is kill.



~~**Terminal UI (TUI)** - New interactive interface~~
~~Location: `containers/tui/`~~
~~Status: Recently added, under active development~~
~~Technology: Python Textual framework~~

   UPDATE: Where were you when TUI is kill? Now.

3. **SecureBoot Bootable Media** - Key feature
   - Script: `create-secureboot-bootable-media.sh`
   - Status: Production-ready <--- you left out the end here- Production-ready.... "is a stretch for anything in this repo."
   - Usage: Use the phoenixboot cli for various options to generate secure keys and apply them.

### Maintenance Needed

1. **Legacy Demo Code** - Needs cleanup
   - Location: `examples_and_samples/demo/legacy/`
   - Action: Consider archiving or documenting status
   UPDATE: Legacy demo code still needs a lot of cleanup. Esp. NuclearBoot.

2. **Python Type Hints** - Partial coverage
   - Many older utilities lack type annotations
   - Gradual migration recommended
   UPDATE: we should be better about this, we're kind of working on it, but also I don't care that much as long as this works.

3. **Documentation Consolidation**
   - 40+ markdown files with some overlap
   - Consider organizing into docs/ subdirectories
   UPDATE: Yes. I'm updating documentation literally as I type this.

### Security Sensitive Areas

1. **Key Management** - Critical paths
   - ~~Scripts: `scripts/secure-boot/`, `scripts/mok-management/`~~
   - UPDATE: use the phoenixboot cli.
   - Always review changes carefully
   - UPDATE: keep files below 600ish lines or split into logical modules please. For easy reviewability.
   
2. **UEFI Applications** - Low-level code
   - Source: `staging/src/`
   - Requires EDK2 expertise
   UPDATE: apparently it doesn't because I wrote it and had never used EDK2. Now I just need to get it to compile.

3. **Subprocess Usage** - Potential injection risks
   - Check: All Python files using subprocess/os.system
   - Rule: Always use command lists, never shell=True with user input
   UPDATE: as long as we're not using a remote API it's fine to use shell=True.

## Areas for Contribution

- Python type hints for older modules
- Additional test coverage
- Documentation improvements
- Hardware compatibility testing <--- especially valuable.
- BIOS contributions mapped to hardware in some structured format (JSON preferred) <--- especially valuable.
- A BIOS finder utility via scraping and some AI or something <----- especially valuable.

## Notes

Update this file when priorities shift or new hotspots emerge.
Last updated: ~~2026-01-30~~ 2026-05-06
