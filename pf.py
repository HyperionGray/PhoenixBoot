#!/usr/bin/env bash
# PhoenixBoot task runner shim.
#
# This script delegates to the upstream `pf` task runner, which reads task
# definitions from the *.pf files at the repo root (Pfyfile.pf and friends).
#
# `pf` is not a pip package. It is installed by cloning
# https://github.com/P4X-ng/pf-runner and putting `pf-cli-base/pf_parser.py`
# on PATH as `pf`. See docs/AGENTS.md for the full recipe.

set -euo pipefail

if command -v pf >/dev/null 2>&1; then
  exec pf "$@"
fi

cat >&2 <<'EOF'
phoenixboot ERROR: the `pf` task runner is not on PATH.

PhoenixBoot uses the `pf` runner (from P4X-ng/pf-runner) as its primary
task interface. The wrapper at ./pf.py simply forwards arguments to it.

To install `pf` on a fresh machine:

    git clone https://github.com/P4X-ng/pf-runner ~/.local/src/pf-runner
    pip install --user fabric lark
    install -m 0755 ~/.local/src/pf-runner/pf-cli-base/pf_parser.py \
        ~/.local/bin/pf

Make sure ~/.local/bin is on PATH, then re-run your command.

Alternatives that work without `pf`:

  - ./phoenixboot help                # curated wrapper, see also `list`
  - bash scripts/<subdir>/<script>.sh # run individual scripts directly

For the supported alpha feature set see ALPHA_RELEASE_PLAN.md.
EOF
exit 127
