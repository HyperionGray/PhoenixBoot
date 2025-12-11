#!/usr/bin/env bash
# Description: Generates Secure Boot keypairs (PK, KEK, db).

set -euo pipefail

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         🔐 Generating SecureBoot Key Hierarchy 🔐            ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "This will create a complete SecureBoot key hierarchy:"
echo ""
echo "  📌 PK  (Platform Key)        - Root of trust, owns your system"
echo "  📌 KEK (Key Exchange Key)    - Intermediate authority"
echo "  📌 db  (Signature Database)  - Authorizes bootloaders & kernels"
echo ""

# PK
if [ -f keys/PK.key ]; then
    echo "✓ PK key already exists, skipping generation"
else
    echo "→ Generating PK (Platform Key)..."
    openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
        -subj "/CN=PhoenixGuard PK/O=PhoenixGuard/C=US" -keyout keys/PK.key -out keys/PK.crt
    echo "  ✓ Created keys/PK.key and keys/PK.crt"
fi
openssl x509 -in keys/PK.crt -outform DER -out keys/PK.cer
chmod 600 keys/PK.key || true

# KEK
if [ -f keys/KEK.key ]; then
    echo "✓ KEK key already exists, skipping generation"
else
    echo "→ Generating KEK (Key Exchange Key)..."
    openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
        -subj "/CN=PhoenixGuard KEK/O=PhoenixGuard/C=US" -keyout keys/KEK.key -out keys/KEK.crt
    echo "  ✓ Created keys/KEK.key and keys/KEK.crt"
fi
openssl x509 -in keys/KEK.crt -outform DER -out keys/KEK.cer
chmod 600 keys/KEK.key || true

# db
if [ -f keys/db.key ]; then
    echo "✓ db key already exists, skipping generation"
else
    echo "→ Generating db (Signature Database)..."
    openssl req -new -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
        -subj "/CN=PhoenixGuard db/O=PhoenixGuard/C=US" -keyout keys/db.key -out keys/db.crt
    echo "  ✓ Created keys/db.key and keys/db.crt"
fi
openssl x509 -in keys/db.crt -outform DER -out keys/db.cer
chmod 600 keys/db.key || true

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ SecureBoot keys generated successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📁 Key files saved to: ./keys/"
echo ""
echo "   PK.key, PK.crt, PK.cer   - Platform Key (ROOT OF TRUST)"
echo "   KEK.key, KEK.crt, KEK.cer - Key Exchange Key"
echo "   db.key, db.crt, db.cer    - Signature Database"
echo ""
echo "🔒 SECURITY NOTE: Keep .key files PRIVATE! They control your system's boot security."
echo ""
echo "📚 What to do next:"
echo ""
echo "  1️⃣  Create authenticated enrollment files:"
echo "     ./pf.py secure-make-auth"
echo ""
echo "  2️⃣  Use these keys to sign bootloaders (like BOOTX64.EFI)"
echo "     They're automatically used when you run './pf.py build-package-esp'"
echo ""
echo "  3️⃣  Enroll them on your system using KeyEnrollEdk2.efi"
echo "     (Included in bootable media created by './pf.py secureboot-create')"
echo ""
echo "💡 TIP: For a complete SecureBoot bootable USB, run:"
echo "     ISO_PATH=/path/to/your.iso ./pf.py secureboot-create"
echo ""

