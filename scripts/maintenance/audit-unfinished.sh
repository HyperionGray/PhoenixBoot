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
  "docs/implementation"
  "docs/reviews"
)

EXCLUDE_ARGS=()
for dir in "${EXCLUDE_DIRS[@]}"; do
  EXCLUDE_ARGS+=(--glob "!${dir}/**")
done

PATTERN='TODO|FIXME|STUB|TBD|XXX|UNFINISHED|WIP'

{
  echo "PhoenixBoot unfinished markers audit"
  echo "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo
} > "$REPORT_FILE"

if rg -n --ignore-case "$PATTERN" \
    "${EXCLUDE_ARGS[@]}" \
    --glob "*.{py,sh,md,yml,yaml,pf,c,h,txt}" \
    . >> "$REPORT_FILE"; then
  echo
  echo "Found unfinished markers. See: $REPORT_FILE"
  exit 2
fi

echo "No unfinished markers found in audited production paths." >> "$REPORT_FILE"
echo "Audit clean. See: $REPORT_FILE"
