#!/usr/bin/env bash
# Description: Creates ESL and AUTH files for Secure Boot variables.

set -euo pipefail

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

mkdir -p out/securevars

echo "→ Creating PK (Platform Key) enrollment file..."
echo "  (Self-signed by PK - root of trust)"
# PK self-signed
cert-to-efi-sig-list -g $(uuidgen) keys/PK.cer out/securevars/PK.esl
sign-efi-sig-list -k keys/PK.key -c keys/PK.crt PK out/securevars/PK.esl out/securevars/PK.auth
echo "  ✓ Created: out/securevars/PK.auth"

echo ""
echo "→ Creating KEK (Key Exchange Key) enrollment file..."
echo "  (Signed by PK - can update db)"
# KEK signed by PK
cert-to-efi-sig-list -g $(uuidgen) keys/KEK.cer out/securevars/KEK.esl
sign-efi-sig-list -k keys/PK.key -c keys/PK.crt KEK out/securevars/KEK.esl out/securevars/KEK.auth
echo "  ✓ Created: out/securevars/KEK.auth"

echo ""
echo "→ Creating db (Signature Database) enrollment file..."
echo "  (Signed by KEK - authorizes bootloaders)"
# db signed by KEK
cert-to-efi-sig-list -g $(uuidgen) keys/db.cer out/securevars/db.esl
sign-efi-sig-list -k keys/KEK.key -c keys/KEK.crt db out/securevars/db.esl out/securevars/db.auth
echo "  ✓ Created: out/securevars/db.auth"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Enrollment files created successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📁 Output location: out/securevars/"
echo ""
echo "   PK.auth  - Platform Key enrollment file"
echo "   KEK.auth - Key Exchange Key enrollment file"
echo "   db.auth  - Signature Database enrollment file"
echo ""
echo "   (Also created: .esl intermediate files)"
echo ""
echo "📚 What to do next:"
echo ""
echo "  1️⃣  These .auth files are used by KeyEnrollEdk2.efi"
echo "     (Automatically included when you create bootable media)"
echo ""
echo "  2️⃣  Create complete SecureBoot bootable media:"
echo "     ISO_PATH=/path/to/your.iso ./pf.py secureboot-create"
echo ""
echo "  3️⃣  Boot from the media and select:"
echo "     'Enroll PhoenixGuard SecureBoot Keys' from GRUB menu"
echo ""
echo "  4️⃣  After enrollment, enable SecureBoot in BIOS/UEFI"
echo ""
echo "💡 TIP: The .auth files contain your public keys + signatures"
echo "   They're safe to share (but keep the .key files private!)"
echo ""
echo "🔗 For manual enrollment instructions, see: docs/SECURE_BOOT.md"
echo ""

