#!/usr/bin/env bash
# Description: Creates ESL and AUTH files for Secure Boot variables.

set -euo pipefail

# Resolve project-relative paths so script works from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
KEYS_DIR="$PROJECT_ROOT/keys"
OUT_DIR="$PROJECT_ROOT/out/securevars"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║    🔐 Creating SecureBoot Enrollment Files (.auth) 🔐        ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "This creates authenticated enrollment files for your UEFI firmware."
echo "These .auth files are used by KeyEnrollEdk2.efi to enroll keys."
echo ""

mkdir -p "$OUT_DIR"

echo "→ Creating PK (Platform Key) enrollment file..."
echo "  (Self-signed by PK - root of trust)"
# PK self-signed
cert-to-efi-sig-list -g "$(uuidgen)" "$KEYS_DIR/PK.cer" "$OUT_DIR/PK.esl"
sign-efi-sig-list -k "$KEYS_DIR/PK.key" -c "$KEYS_DIR/PK.crt" PK "$OUT_DIR/PK.esl" "$OUT_DIR/PK.auth"
echo "  ✓ Created: $OUT_DIR/PK.auth"

echo ""
echo "→ Creating KEK (Key Exchange Key) enrollment file..."
echo "  (Signed by PK - can update db)"
# KEK signed by PK
cert-to-efi-sig-list -g "$(uuidgen)" "$KEYS_DIR/KEK.cer" "$OUT_DIR/KEK.esl"
sign-efi-sig-list -k "$KEYS_DIR/PK.key" -c "$KEYS_DIR/PK.crt" KEK "$OUT_DIR/KEK.esl" "$OUT_DIR/KEK.auth"
echo "  ✓ Created: $OUT_DIR/KEK.auth"

echo ""
echo "→ Creating db (Signature Database) enrollment file..."
echo "  (Signed by KEK - authorizes bootloaders)"
# db signed by KEK
cert-to-efi-sig-list -g "$(uuidgen)" "$KEYS_DIR/db.cer" "$OUT_DIR/db.esl"
sign-efi-sig-list -k "$KEYS_DIR/KEK.key" -c "$KEYS_DIR/KEK.crt" db "$OUT_DIR/db.esl" "$OUT_DIR/db.auth"
echo "  ✓ Created: $OUT_DIR/db.auth"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Enrollment files created successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📁 Output location: $OUT_DIR/"
echo ""
echo "   PK.auth  - Platform Key enrollment file"
echo "   KEK.auth - Key Exchange Key enrollment file"
echo "   db.auth  - Signature Database enrollment file"
echo ""
echo "   (Also created: .esl intermediate files)"
echo ""
echo "📚 What to do next:"
echo ""
echo "  1️⃣  Use these .auth files to enroll PK/KEK/db in firmware"
echo "     See: docs/SECUREBOOT_ENABLEMENT_KEXEC.md"
echo ""
echo "  2️⃣  After enrollment, enable SecureBoot in BIOS/UEFI"
echo ""
echo "💡 TIP: The .auth files contain your public keys + signatures"
echo "   They're safe to share (but keep the .key files private!)"
echo ""
echo "🔗 For manual enrollment instructions, see: docs/SECURE_BOOT.md"
echo ""
