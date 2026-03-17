#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# List MOK certs/keys and show enrollment status.
# Usage: mok-list-keys.sh [--json] [--enrolled-only] [--skip-enrollment-check]
# Scans out/keys/mok (new layout) and legacy out/keys for compatibility.

MOK_DIR="out/keys/mok"
LEGACY_DIR="out/keys"
JSON_MODE=0
ENROLLED_ONLY=0
SKIP_ENROLLMENT_CHECK=0
ENROLLMENT_CHECK_AVAILABLE=0
ENROLLED_LIST_UPPER=""

usage() {
  cat <<'EOF'
Usage: mok-list-keys.sh [options]

Options:
  --json                    Emit machine-readable JSON inventory.
  --enrolled-only           Only include enrolled certificates.
  --skip-enrollment-check   Skip mokutil enrollment detection.
  -h, --help                Show this help.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json)
      JSON_MODE=1
      ;;
    --enrolled-only)
      ENROLLED_ONLY=1
      ;;
    --skip-enrollment-check)
      SKIP_ENROLLMENT_CHECK=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

list_certs() {
  # Prefer new layout; include legacy as fallback
  if [ -d "$MOK_DIR" ]; then
    find "$MOK_DIR" -maxdepth 2 -type f \( -name '*.crt' -o -name '*.pem' -o -name '*.cer' -o -name '*.der' \)
  fi
  if [ -d "$LEGACY_DIR" ]; then
    find "$LEGACY_DIR" -maxdepth 1 -type f \( -name '*.crt' -o -name '*.pem' -o -name '*.cer' -o -name '*.der' \)
  fi
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

sha1_fp() {
  local f="$1"
  case "${f##*.}" in
    der|cer) openssl x509 -inform DER -in "$f" -noout -fingerprint -sha1 2>/dev/null | sed 's/^SHA1 Fingerprint=//' | tr '[:lower:]' '[:upper:]' ;;
    crt|pem) openssl x509 -in "$f" -noout -fingerprint -sha1 2>/dev/null | sed 's/^SHA1 Fingerprint=//' | tr '[:lower:]' '[:upper:]' ;;
    *) return 1 ;;
  esac
}

subject_of() {
  local f="$1"
  case "${f##*.}" in
    der|cer) openssl x509 -inform DER -in "$f" -noout -subject 2>/dev/null | sed 's/^subject= *//' ;;
    crt|pem) openssl x509 -in "$f" -noout -subject 2>/dev/null | sed 's/^subject= *//' ;;
    *) return 1 ;;
  esac
}

issuer_of() {
  local f="$1"
  case "${f##*.}" in
    der|cer) openssl x509 -inform DER -in "$f" -noout -issuer 2>/dev/null | sed 's/^issuer= *//' ;;
    crt|pem) openssl x509 -in "$f" -noout -issuer 2>/dev/null | sed 's/^issuer= *//' ;;
    *) return 1 ;;
  esac
}

not_after_of() {
  local f="$1"
  case "${f##*.}" in
    der|cer) openssl x509 -inform DER -in "$f" -noout -enddate 2>/dev/null | sed 's/^notAfter=//' ;;
    crt|pem) openssl x509 -in "$f" -noout -enddate 2>/dev/null | sed 's/^notAfter=//' ;;
    *) return 1 ;;
  esac
}

key_path() {
  local cert="$1"
  local base="${cert%.*}"
  if [ -f "$base.key" ]; then
    printf '%s' "$base.key"
    return 0
  fi
  if [ -f "${cert%.crt}.key" ]; then
    printf '%s' "${cert%.crt}.key"
    return 0
  fi
  return 1
}

init_enrollment_cache() {
  local enrolled_raw=""
  if [ "$SKIP_ENROLLMENT_CHECK" = "1" ]; then
    return
  fi
  if ! command -v mokutil >/dev/null 2>&1; then
    return
  fi

  if enrolled_raw="$(mokutil --list-enrolled 2>/dev/null)"; then
    ENROLLMENT_CHECK_AVAILABLE=1
  elif enrolled_raw="$(sudo -n mokutil --list-enrolled 2>/dev/null)"; then
    ENROLLMENT_CHECK_AVAILABLE=1
  else
    return
  fi
  ENROLLED_LIST_UPPER="$(printf '%s\n' "$enrolled_raw" | tr '[:lower:]' '[:upper:]')"
}

has_key() {
  local cert="$1"
  key_path "$cert" >/dev/null 2>&1
}

is_enrolled() {
  local fp="$1"
  if [ "$SKIP_ENROLLMENT_CHECK" = "1" ] || [ "$ENROLLMENT_CHECK_AVAILABLE" != "1" ]; then
    echo "unknown"
    return
  fi
  if printf '%s\n' "$ENROLLED_LIST_UPPER" | grep -Fq "$fp"; then
    echo "true"
  else
    echo "false"
  fi
}

init_enrollment_cache

idx=0
matched=0
enrolled_count=0
key_count=0
first_json=1
cert_json_payload=""

if [ "$JSON_MODE" != "1" ]; then
  printf "%-4s %-9s %-9s %-42s %s\n" "#" "ENROLLED" "KEY" "FINGERPRINT(SHA1)" "CERT"
fi
while IFS= read -r cert; do
  [ -n "$cert" ] || continue
  fp=$(sha1_fp "$cert" || true)
  [ -n "$fp" ] || continue
  enrolled_state="$(is_enrolled "$fp")"
  if [ "$ENROLLED_ONLY" = "1" ] && [ "$enrolled_state" != "true" ]; then
    continue
  fi

  matched=$((matched+1))
  idx=$((idx+1))

  if [ "$enrolled_state" = "true" ]; then
    e="YES"
    enrolled_json="true"
    enrolled_count=$((enrolled_count+1))
  elif [ "$enrolled_state" = "false" ]; then
    e="no"
    enrolled_json="false"
  else
    e="unk"
    enrolled_json="null"
  fi

  key_file=""
  if key_file="$(key_path "$cert" 2>/dev/null)"; then
    k="YES"
    key_json="true"
    key_count=$((key_count+1))
  else
    k="no"
    key_json="false"
  fi

  cert_subject="$(subject_of "$cert" || true)"
  cert_issuer="$(issuer_of "$cert" || true)"
  cert_not_after="$(not_after_of "$cert" || true)"

  if [ "$JSON_MODE" = "1" ]; then
    entry=$(
      printf '    {\n'
      printf '      "path": "%s",\n' "$(json_escape "$cert")"
      printf '      "sha1": "%s",\n' "$(json_escape "$fp")"
      printf '      "subject": "%s",\n' "$(json_escape "$cert_subject")"
      printf '      "issuer": "%s",\n' "$(json_escape "$cert_issuer")"
      printf '      "not_after": "%s",\n' "$(json_escape "$cert_not_after")"
      printf '      "enrolled": %s,\n' "$enrolled_json"
      printf '      "has_private_key": %s,\n' "$key_json"
      if [ "$key_json" = "true" ]; then
        printf '      "private_key_path": "%s"\n' "$(json_escape "$key_file")"
      else
        printf '      "private_key_path": null\n'
      fi
      printf '    }'
    )
    if [ $first_json -eq 1 ]; then
      cert_json_payload="$entry"
      first_json=0
    else
      cert_json_payload="${cert_json_payload}"$',\n'"${entry}"
    fi
  else
    sel=""
    if [ "${KMOD_CERT:-}" = "$cert" ]; then sel="*"; fi
    printf "%-4s %-9s %-9s %-42s %s%s\n" "$idx" "$e" "$k" "$fp" "$cert" "$sel"
    eval "CERT_$idx=\"$cert\""
  fi
done < <(list_certs 2>/dev/null | sort -u)

if [ "$matched" = 0 ]; then
  if [ "$JSON_MODE" = "1" ]; then
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ "$SKIP_ENROLLMENT_CHECK" = "1" ]; then
      enrollment_mode="skipped"
    elif [ "$ENROLLMENT_CHECK_AVAILABLE" = "1" ]; then
      enrollment_mode="enabled"
    else
      enrollment_mode="unavailable"
    fi
    cat <<EOF
{
  "generated_at_utc": "$now",
  "mok_dir": "$MOK_DIR",
  "legacy_dir": "$LEGACY_DIR",
  "enrollment_check": "$enrollment_mode",
  "certificates": [],
  "summary": {
    "total": 0,
    "enrolled": 0,
    "with_private_key": 0
  }
}
EOF
    exit 0
  fi
  echo "(No candidate MOK certificates found under $MOK_DIR or $LEGACY_DIR)"
  exit 0
fi

if [ "$JSON_MODE" = "1" ]; then
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ "$SKIP_ENROLLMENT_CHECK" = "1" ]; then
    enrollment_mode="skipped"
  elif [ "$ENROLLMENT_CHECK_AVAILABLE" = "1" ]; then
    enrollment_mode="enabled"
  else
    enrollment_mode="unavailable"
  fi
  printf '{\n'
  printf '  "generated_at_utc": "%s",\n' "$now"
  printf '  "mok_dir": "%s",\n' "$MOK_DIR"
  printf '  "legacy_dir": "%s",\n' "$LEGACY_DIR"
  printf '  "enrollment_check": "%s",\n' "$enrollment_mode"
  printf '  "certificates": [\n'
  if [ -n "$cert_json_payload" ]; then
    printf '%s\n' "$cert_json_payload"
  fi
  printf '\n  ],\n'
  printf '  "summary": {\n'
  printf '    "total": %s,\n' "$matched"
  printf '    "enrolled": %s,\n' "$enrolled_count"
  printf '    "with_private_key": %s\n' "$key_count"
  printf '  }\n'
  printf '}\n'
  exit 0
fi

echo
if [ -n "${KMOD_CERT:-}" ]; then
  echo "Selected: KMOD_CERT=$KMOD_CERT"
  [ -n "${KMOD_KEY:-}" ] && echo "          KMOD_KEY=$KMOD_KEY" || true
fi
