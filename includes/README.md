# Shared includes

This directory centralizes shared include-style content for componentized parts of PhoenixBoot.

- `lib/` holds shared shell helpers such as `common.sh`
- `core/`, `secure/`, `workflows/`, and `maint/` point at each component's local `include/` directory

The legacy `scripts/lib/` path is kept as a compatibility symlink to `includes/lib/`.
