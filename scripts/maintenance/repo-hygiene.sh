#!/usr/bin/env bash
# Repository hygiene checks and optional cleanup for generated/stale files.
# Usage:
#   bash scripts/maintenance/repo-hygiene.sh         # check mode (default)
#   APPLY=1 bash scripts/maintenance/repo-hygiene.sh # apply cleanup

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

APPLY="${APPLY:-0}"

info() {
    printf '%s\n' "$*"
}

is_tracked_path() {
    local path="$1"
    git ls-files --error-unmatch "$path" >/dev/null 2>&1
}

remove_path() {
    local path="$1"
    if [ "$APPLY" = "1" ]; then
        git rm -r -- "$path" >/dev/null
        info "REMOVED: $path"
    else
        info "FOUND:   $path"
    fi
}

info "Repository hygiene scan"
info "Mode: $( [ "$APPLY" = "1" ] && echo apply || echo check )"
info ""

# Patterns for generated artifact directories/files we should not track.
tracked_target_count="$( (git ls-files | rg "^examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target/" || true) | wc -l | tr -d '[:space:]' )"
tracked_debug_log_count="$( (git ls-files | rg "^examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/debug\\.log$" || true) | wc -l | tr -d '[:space:]' )"

if [ "$tracked_target_count" -gt 0 ]; then
    remove_path "examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/target"
else
    info "OK:      no tracked legacy Rust target/ artifacts"
fi

if [ "$tracked_debug_log_count" -gt 0 ]; then
    remove_path "examples_and_samples/demo/legacy-old/examples/nuclear-boot-rust/debug.log"
else
    info "OK:      no tracked legacy debug.log artifact"
fi

info ""
if [ "$APPLY" = "1" ]; then
    info "Hygiene cleanup apply complete."
    info "Review changes with: git status --short"
else
    info "Hygiene check complete."
    info "Apply cleanup with: APPLY=1 bash scripts/maintenance/repo-hygiene.sh"
fi
