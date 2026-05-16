# examples_and_samples

This directory used to ship ~449 MB of demonstration content directly in
the repo:

- ASUS ROG G615LP BIOS dumps and update installers
- Vendor `.exe` driver installers (Intel ME, NPU, MEI, etc.)
- A Rust `no_std` PoC bootloader (`nuclear-boot-rust/`)
- Compiled Rust `target/` artifacts
- Sample SecureBoot certs **including real-looking private keys**

For the `v0.1.0-alpha` release we removed all of that from version
control. The reasons are in
[`../ALPHA_RELEASE_PLAN.md`](../ALPHA_RELEASE_PLAN.md) §3.6 and §3.2:

- Vendor BIOS dumps and `.exe` driver installers have unclear (and
  almost certainly Apache-2.0 incompatible) redistribution rights.
- The sample certs included real RSA private keys that should never
  have been on a public branch.
- The `target/` tree alone was ~123 MB of compiled artifacts.
- The whole tree dominated the repo size and made the alpha tarball
  unnecessarily large.

## What lives here now

- This `README.md` (kept tracked so contributors can find this note).
- Everything else in this directory is `.gitignore`d. If you regenerate
  the demo content locally for development, it will not be committed.

## Where the still-useful pieces moved

- The Rust `no_std` PoC bootloader moved to
  [`../experimental/nuclear-boot-rust/`](../experimental/nuclear-boot-rust/).
  Source only, no `target/`. It is part of the experimental tree, not
  the alpha API — see
  [`../experimental/README.md`](../experimental/README.md).

## Where sample BIOS dumps + demo media should live

Per `ALPHA_RELEASE_PLAN.md` §6, the plan is a separate
`phoenixboot-samples` repository (or a release-asset bucket) with an
explicit license statement covering the vendor binaries. Until that
exists, contributors who need a sample BIOS image to test against
should obtain it from the vendor directly or from their own machine
(`flashrom -r firmware.bin` on supported hardware).
