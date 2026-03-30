#!/usr/bin/env bash
# Audit non-demo code for unfinished work markers.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

mkdir -p out/audit
REPORT_FILE="out/audit/unfinished-markers.txt"

EXCLUDE_DIRS=(
  ".git"
  "out"
  "examples_and_samples"
  "dev/wip"
  "demo"
  "staging/src"
  "staging/boot"
  "docs/implementation"
  "docs/reviews"
)

EXCLUDE_ARGS=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=(--glob "!${dir}/**")
done

# Match common unfinished markers when used as comment tags, e.g.:
#   # TODO: ...
#   // FIXME ...
#   /* TODO ... */
# This avoids false positives like "wipe" matching "wip".
PATTERN='^\s*(#|//|/\*+|--)\s*(TODO|FIXME|STUB|TBD|XXX|UNFINISHED|WIP)\b'

{
  echo "PhoenixBoot unfinished markers audit"
  echo "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo
} > "$REPORT_FILE"

if rg -n --ignore-case "$PATTERN" \
    "${EXCLUDE_ARGS[@]}" \
    --glob "*.{py,sh,yml,yaml,pf,c,h}" \
    . >> "$REPORT_FILE"; then
  echo
  echo "Found unfinished markers. See: $REPORT_FILE"
  exit 2
fi

echo "No unfinished markers found in audited production paths." >> "$REPORT_FILE"
echo "Audit clean. See: $REPORT_FILE"
