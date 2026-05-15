# PhoenixBoot — Experimental

Everything under this directory is **not part of the alpha API**.

The code here is interesting, sometimes runnable, sometimes pure
prototype. It is excluded from CI, has no compatibility guarantees, and
may be rewritten or deleted at any time.

If you are looking for the supported surface for the `v0.1.0-alpha`
release, see [`ALPHA_RELEASE_PLAN.md`](../ALPHA_RELEASE_PLAN.md) at the
repo root.

## Contents

| Path | What it is | Status |
|---|---|---|
| `universal-bios/` | Universal BIOS generator (formerly `dev/wip/universal-bios/`). Aims to build firmware artifacts for arbitrary hardware. | Prototype. Hardware compatibility matrix incomplete. Platform-specific boot paths need validation. |
| `universal-bios-plus/` | Newer rewrite (formerly `dev/universal_bios/`). | Single-file `universal_bios_plus.py`; not wired into any task. |
| `scrapers/` | Distributed crowdsourced hardware scraping (formerly `dev/scrapers/`). | Pipeline incomplete; no server. |
| `hardware-database/` | Static scraped hardware data (formerly `dev/hardware_database/`). | Sample data only. |
| `scraped-hardware/` | More scraped hardware data (formerly `dev/scraped_hardware/`). | Sample data only. |
| `firmware-recovery-dev/` | Older parallel copy of `utils/hardware_firmware_recovery.py` plus flashrom helpers (formerly `dev/tools/`). | Superseded by `utils/hardware_firmware_recovery.py`; kept here for diffs only. |
| `cloud-integration/` | API sketches for a cooperative defense / cloud attestation service (formerly `ideas/cloud_integration/`). | Concept code, no server, no auth. |
| `web/` | Flask "hardware database" prototype server (formerly `web/`). | Demo only, no auth, do not expose. |
| `nuclear-boot-rust/` | Rust `no_std` PoC of a network-booted, attested bootloader (formerly under `examples_and_samples/demo/legacy-old/`). | PoC. Source only; build artifacts (`target/`) are gitignored. |

## Reading the canonical implementation

When two copies of a file exist (e.g. `experimental/firmware-recovery-dev/hardware_firmware_recovery.py`
vs. `utils/hardware_firmware_recovery.py`), the version under `utils/` is
the one that the `pf` tasks call and the one we will keep maintained.
The `experimental/` copy is preserved only so historical diffs are
readable.

## Will this ship?

Maybe. Items in `experimental/` graduate to the supported surface only
after they have:

1. A `pf` task wired up in one of the component `*.pf` files.
2. A short README or doc page under `docs/`.
3. At least one smoke test in CI.
4. A maintainer who has signed up to support it.

If you want to push something out of `experimental/`, open an issue
referencing the relevant gap in `ALPHA_RELEASE_PLAN.md`.
