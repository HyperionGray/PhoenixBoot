#!/usr/bin/env bash
# PhoenixBoot task runner shim.
#
# pf-runner is vendored at ./pf-runner/ in this repo. The ./pf symlink
# at the repo root points at ./pf-runner/pf and is the recommended
# entrypoint. This ./pf.py shim exists so that the many existing pf
# task definitions that say `shell ./pf.py <task>` keep working; it
# simply forwards to the vendored ./pf, then to any pf that happens to
# be on PATH (e.g. one installed via `pip install -e ./pf-runner`).

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -x "${HERE}/pf" ]; then
  exec "${HERE}/pf" "$@"
fi

if command -v pf >/dev/null 2>&1; then
  exec pf "$@"
fi

cat >&2 <<EOF
phoenixboot ERROR: cannot find a pf task runner.

PhoenixBoot ships pf-runner vendored under ./pf-runner/ and exposes it
via the ./pf symlink at the repo root. Neither ./pf nor a system-wide
\`pf\` on PATH was found from this script's directory:

    ${HERE}

If you cloned the repo without the vendored pf-runner/ tree (e.g. a
shallow checkout that excluded it), restore it with:

    git checkout -- pf-runner pf

If the vendored copy is present but ./pf is missing python deps, run:

    pip install --user -e ./pf-runner

Then re-run your command. See ALPHA_RELEASE_PLAN.md and docs/AGENTS.md
for the full alpha install story.
EOF
exit 127
