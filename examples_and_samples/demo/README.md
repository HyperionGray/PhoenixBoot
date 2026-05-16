# PhoenixBoot demo and archive content

This directory is **not part of the release surface**. It holds archived demos, testing scraps, and reference material that are excluded from production builds and release-facing workflows.

Use the real functionality from the repository root instead:
- `./create-secureboot-bootable-media.sh --iso /path/to/os.iso` for install media
- `./pf.py secure-env` for host-side security checks
- `./pf.py uuefi-report` for read-only host UEFI reporting
- `./phoenixboot-wizard.sh` for the guided workflow

Anything left under `examples_and_samples/demo/` should be treated as experimental/dev or archival until it is wired into the main product flow.
