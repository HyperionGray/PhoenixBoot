# PhoenixBoot Alpha Release — Gap Analysis & Plan

> Status: working document for the first OSS alpha tag (`v0.1.0-alpha`).
> Owners: maintainers + cloud agent automation.
> Last updated: 2026-05-15.

This document is the single source of truth for what the OSS alpha will contain.
It captures (1) the surface that ships, (2) what is gated to `experimental/`,
(3) the cleanup work that must land before tagging, and (4) the things we are
explicitly *not* shipping yet.

If a feature is not listed here, treat it as out-of-scope for `v0.1.0-alpha`.

---

## 1. Alpha scope ("supported in the alpha")

These are the features we are willing to put a quality label on. They have
working scripts, working `pf` tasks, documentation, and at least smoke tests.

### 1.1 Secure Boot key lifecycle
- Generate a PK / KEK / db key hierarchy (`./pf.py secure-keygen`,
  `./phoenixboot secure keygen`).
- Build `.esl` / `.auth` enrollment bundles (`secure-make-auth`).
- Enroll keys in OVMF for testing (`secure-enroll-secureboot`).
- Inspect host Secure Boot status (`secureboot-check`,
  `./phoenixboot secure check`).
- Centralize / prune key locations (`secure-keys-centralize`,
  `secure-keys-prune`).

### 1.2 MOK (Machine Owner Key) + module signing
- Create a fresh MOK keypair (`secure-mok-new`).
- Enroll / unenroll the MOK (`os-mok-enroll`, `secure-unenroll-mok`).
- List, status, verify, find-enrolled (`os-mok-list-keys`,
  `secure-mok-status`, `secure-mok-verify`, `secure-mok-find-enrolled`).
- Sign one module or a tree of modules (`os-kmod-sign`,
  `./sign-kernel-modules.sh`, `./phoenixboot secure kmod-sign`).

### 1.3 Secure Boot bootable media
- Turnkey "give me an ISO, get a Secure-Boot-ready USB image"
  (`./create-secureboot-bootable-media.sh`, `secureboot-create`,
  `secureboot-create-usb`, `./phoenixboot secure media`).
- Key enrollment tool bundled on the media; Microsoft-signed shim path
  supported.

### 1.4 ESP packaging + UEFI binaries
- Prebuilt EFI binaries shipped from `staging/boot/`:
  - `NuclearBootEdk2.efi` — attestation-enforced bootloader.
  - `KeyEnrollEdk2.efi` — first-boot key enroller.
  - `UUEFI.efi` v3.2 — diagnostic / management tool.
- ESP image building (`build-package-esp`).
- ESP validation (`verify-esp-robust`, `validate-all`).
- Negative-attestation ESP for testing (`build-package-esp-neg-attest`).

### 1.5 QEMU end-to-end tests
- `test-qemu`, `test-qemu-secure-positive`, `test-qemu-secure-strict`,
  `test-qemu-secure-negative-attest`, `test-qemu-uuefi`.
- JUnit XML output under `out/qemu/`.
- CI workflow covers these (`.github/workflows/e2e-tests.yml`).

### 1.6 Security environment / kernel hardening / DoD
- Full security environment check (`secure-env`).
- Kernel hardening analyzer + reports (`kernel-hardening-*`,
  `kernel-config-*`, `kernel-profile-*`).
- Firmware checksum DB (`firmware-checksum-*`).
- DISA STIG helper (`dod-info`, `dod-stig-check`, `dod-secure-config`).

### 1.7 UUEFI host-side helpers
- `uuefi-install`, `uuefi-apply`, `uuefi-report` (require root /
  `efibootmgr`).

### 1.8 CLIs and runners
- `./pf` — symlink to the vendored `pf-runner/pf` launcher. This is the
  recommended user-facing entrypoint for all task work
  (`./pf list`, `./pf <task>`). pf-runner is vendored under
  [`pf-runner/`](pf-runner/) at a pinned single version; future upgrades
  are intentional and manual, not automated.
- `./pf.py` — bash shim kept for backward compatibility with the many
  existing pf task bodies that say `shell ./pf.py <task>`. It prefers
  the vendored `./pf`, falls back to a pip-installed `pf` on `PATH`,
  and otherwise prints an actionable install hint (see §4).
- `./phoenixboot` (curated, opinionated wrapper, fails loud).
- `./phoenixboot-wizard.sh` (interactive setup wizard).
- `./phoenixboot-tui.sh` (Textual TUI).
- Container images for `build`, `test`, `installer`, `runtime`, `tui`.

> **Why vendored, not a submodule?** pf-runner is our own DSL, the
> repo uses only four of its directives (`task`, `describe`, `include`,
> `shell`), and submodules add real contributor friction (must remember
> `git clone --recursive`, must `pip install` runtime deps anyway,
> must keep the submodule rev in lockstep). A pinned vendored copy
> means a fresh `git clone` is immediately runnable as `./pf` and
> upgrades happen on a schedule we choose.

### 1.9 Maintenance tasks
- `maint-lint`, `maint-format`, `maint-clean`, `cleanup`,
  `maint-install-git-hooks`, `maint-pre-push-check`.
- The pre-push size guard (50 MB cap) is installable via
  `./pf.py maint-install-git-hooks`.

---

## 2. Experimental scope (`experimental/`, NOT alpha quality)

These are interesting, sometimes useful, sometimes prototype-only. They live
under `experimental/` for the alpha. They are excluded from the supported
surface, have no CI coverage, and may be removed or rewritten at any time.

| Area | Lives in | Status |
|---|---|---|
| Universal BIOS generator | `experimental/universal-bios/` | Prototype. Hardware compatibility matrix incomplete. |
| Distributed hardware scraper | `experimental/scrapers/` | Prototype. Crowdsourcing pipeline not finished. |
| Hardware database (scraped) | `experimental/hardware-database/` | Static sample data. |
| Cloud co-op integration | `experimental/cloud-integration/` | API sketches only, no server. |
| Hardware database web server | `experimental/web/` | Flask prototype. |
| Hardware firmware recovery (dev copy) | `experimental/firmware-recovery-dev/` | Older parallel copy of `utils/hardware_firmware_recovery.py`. Canonical version stays in `utils/`. |

A short `experimental/README.md` warns users that nothing in there is part
of the alpha API.

The existing `ideas/` directory continues to hold pure-text future ideas and
is unaffected.

---

## 3. What is being *removed from tracking* for the alpha

These files are in the working tree but should never have been versioned.
For the alpha tag, the tree must be clean. (History rewrite to actually
shrink the repo is a separate, post-alpha decision — see §6.)

### 3.1 User-specific kernel modules (`*.ko` / `*.ko.unsigned`)
Tracked as if they were artifacts; they are actually one developer's signed
modules.

- `beegfs.ko` (57 MB), `beegfs.ko.unsigned` (57 MB)
- `pfs_memhub.ko.unsigned`
- `utils/apfs_unsigned.ko`, `utils/apfs_unsigned.ko.unsigned`
- `utils/pfs_fastpath.ko`, `utils/pfs_fastpath.ko.unsigned`
- `utils/keys/pfs_fastpath.ko`, `utils/keys/pfs_fastpath.ko.unsigned`
- `examples_and_samples/example_kmods/apfs.ko`,
  `examples_and_samples/example_kmods/apfs.ko.unsigned`

### 3.2 Private cryptographic material
`keys/README.md` already says these should be `.gitignore`d. They are not.
For OSS we must not publish any private key, even a "sample".

- `keys/PK.key`, `keys/KEK.key`, `keys/db.key`
- `utils/keys/PK.key`, `utils/keys/KEK.key`, `utils/keys/db.key`,
  `utils/keys/PGMOK.key`, `utils/keys/user_secureboot.key`,
  `utils/keys/user_secureboot.pem`, `utils/keys/user_secureboot.der`,
  `utils/keys/2/user_secureboot.{key,pem,der}`
- `utils/PGMOK.der`, `utils/PGMOK.pem`, `utils/phoenixguard-mok.der`
- `staging/keys/mok/phoenixguard-mok.pem`
- `examples_and_samples/secureboot_certs/example_certs/user_secureboot.{key,pem,der}`

Action: `git rm --cached` all of the above and harden `.gitignore` so they
cannot be re-added by accident. Public `.crt` / `.cer` files stay (they
are public by definition).

### 3.3 Podman / Buildah storage leftovers
These are the contents of `containers-storage:` that escaped onto the
filesystem of whoever last ran a rootless podman command in the repo.

- `overlay/`, `overlay-containers/`, `overlay-images/`,
  `overlay-layers/` (lock files, sqlite DBs, mount-program flags).
- `ovmf_stuff/.bish-index`, `ovmf_stuff/.bish.sqlite` (keep
  `ovmf_stuff/OVMF_VARS.fd` — that one is intentionally used by the QEMU
  tests).

### 3.4 Bish indexer cache (`.bish-index`, `.bish.sqlite`)
54 cache files of a local indexing tool. Nothing references them; they
should never be tracked. Added to `.gitignore`.

### 3.5 Other obvious cruft
- `db.sql` — orphan 112 KB SQLite dump (`ContainerConfig` schema, i.e.
  more podman state).
- `utils/update_just_help.sh` — leftover from the Justfile era (we use
  `pf` now, see `docs/JUSTFILE_MODULARIZATION.md`).
- `utils/libpgmodverify.so.1` — symlink to a non-tracked .so; the build
  produces this, it shouldn't be checked in.

### 3.6 `examples_and_samples/` (~449 MB)
This single directory accounts for the majority of the repo's size:

- `examples_and_samples/official_bios_backup/G615LP/` — vendor BIOS dumps
  of an ASUS ROG laptop. Redistribution rights unclear, almost certainly
  not Apache-2.0 compatible.
- `examples_and_samples/demo/legacy/bak/vm-test-autonuke/phoenixguard-install/drivers/`
  — vendor `.exe` driver installers (ASUS / Intel). Same licensing issue.
- `examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/`
  — compiled Rust build artifacts (`target/`). Should never be tracked.
- `examples_and_samples/demo/legacy/` and `legacy-old/` — multiple
  generations of archived demos.
- `examples_and_samples/secureboot_certs/example_certs/` — sample certs,
  but ships real private keys (see §3.2).

For the alpha, `examples_and_samples/` is **dropped from the tree.** A
short stub at `examples_and_samples/README.md` explains how to obtain
sample BIOS dumps and demo material out-of-band. This makes the alpha
tarball about 50 MB instead of 500 MB and removes the
license/redistribution risk.

---

## 4. CLI gap fixes that must land for alpha

These are concrete, small bugs that block a clean alpha experience.

| # | Symptom | Fix |
|---|---|---|
| 4.1 | `./pf.py` had no hint how to install pf when missing. | pf-runner is now vendored under `pf-runner/` and exposed as `./pf` at the repo root. `pf.py` prefers the vendored copy; if both the vendored copy and a PATH-installed `pf` are missing, it prints an actionable hint pointing at `git checkout -- pf-runner pf` and `pip install --user -e ./pf-runner`. |
| 4.2 | 18 scripts had `cd "$(dirname "$0")/.."` instead of `../..`, breaking `source scripts/lib/common.sh`. | Already fixed (see `TODO.md` §"Bugs Fixed in This Assessment"). Verified during this pass. |
| 4.3 | `scripts/maintenance/lint.sh` wrote to `out/lint/*.log` without `mkdir -p`. | Already fixed. |
| 4.4 | `scripts/esp-packaging/esp-package-enroll.sh` had the wrong `source` path. | Already fixed. |
| 4.5 | `docs/AGENTS.md` still warns about the `esp-package.sh` `cd` bug. | Update doc to reflect post-fix state. |
| 4.6 | `./phoenixboot list` shows "wrapper commands" only when `pf` is unavailable, but the wording is good. | Keep as-is; verified. |

The end-to-end "does anything work without `pf` installed" smoke for the
alpha is `./phoenixboot help`, `./phoenixboot status`, `./phoenixboot list`,
`./pf.py` (with helpful error). All four pass after the fixes in this PR.

---

## 5. Explicitly out of scope for the alpha

These are not bugs, they are not gaps, they are simply not promised in
`v0.1.0-alpha`:

- TPM 2.0 measured boot.
- UEFI capsule updates.
- HSM integration.
- P4X OS integration.
- Live remote attestation API.
- Cooperative cloud-defense network.
- Real-hardware SPI flash extraction beyond the `utils/hardware_firmware_recovery.py`
  framework script (it documents `flashrom` usage; we are not yet shipping
  vendor-specific extraction recipes).
- macOS T2, Chromebook, Android bootloader flows.

---

## 6. Things to do *after* alpha but before beta

Not blocking `v0.1.0-alpha`, but should be tracked openly:

1. **History rewrite to actually shrink the repo.** Removing files from
   `HEAD` does not shrink `.git/`. Once everyone is on board, run
   `git filter-repo` or BFG to strip the 449 MB of vendor binaries and
   private keys out of history. This needs a coordinated re-clone for
   every contributor.
2. **Move sample BIOS dumps and demo media** to a separate
   `phoenixboot-samples` repo with a clear license statement, or to a
   release asset bucket.
3. **Re-evaluate `experimental/`** quarterly. Either graduate or delete.
4. **Doc consolidation.** `docs/` has ~55 markdown files with significant
   overlap (multiple UUEFI guides, multiple CI/CD review rollups, multiple
   changelogs). Target: collapse to a single navigable docs tree.
5. **`out/`-only artifact policy.** Anything generated by a build should
   end up under `out/`, never under the source tree (e.g. `nuclear-cd-build/`
   currently mixes a source `.c` file with build outputs).
6. **`pf` runner bootstrap.** ~~Either vendor `pf` here or provide a
   one-liner installer.~~ Done: pf-runner is vendored under `pf-runner/`
   and exposed as `./pf`. Post-alpha question is how we want to manage
   upgrades to the vendored copy (manual `git subtree pull` from the
   upstream `HyperionGray/pf-web-poly-compile-helper-runner`, or just
   periodic copies; this is intentionally a deliberate, manual cadence).

---

## 7. Definition of "alpha tag is ready"

We can tag `v0.1.0-alpha` when:

- [ ] §3 untracking is merged (no private keys, no vendor binaries, no
      podman storage, no `.bish.*` in `git ls-files`).
- [ ] §4 CLI gap fixes are merged and smoke-tested.
- [ ] §2 experimental code is moved under `experimental/` with a `README`.
- [ ] `README.md` clearly states alpha scope and points at this document.
- [ ] CI is green on the alpha branch.
- [ ] `git ls-files | xargs du -b | sort -rn | head` shows no file larger
      than 10 MB. (The pre-push hook already rejects >50 MB; we want a
      tighter de-facto limit for the alpha.)
- [ ] `./phoenixboot help`, `./phoenixboot status`, `./phoenixboot list`,
      and `./pf.py` (with no `pf` installed) all exit cleanly with
      useful output.
