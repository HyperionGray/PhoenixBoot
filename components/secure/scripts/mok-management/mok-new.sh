#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Generate a new PhoenixGuard Module Owner Key (PGMOK)
# Usage: mok-new.sh [NAME] [CN]
#   NAME: basename for output files (default: PGMOK)
#   CN:   certificate subject Common Name (default: PhoenixGuard Module Key)

NAME=${1:-PGMOK}
CN=${2:-PhoenixGuard Module Key}
OUT_DIR="out/keys/mok"
mkdir -p "$OUT_DIR"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         🔑 Generating MOK (Machine Owner Key) 🔑             ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "📌 What is a MOK?"
echo "   MOK (Machine Owner Key) is used to sign kernel modules so they"
echo "   can be loaded when SecureBoot is enabled. Without a signed MOK,"
echo "   your custom or third-party kernel modules will be rejected!"
echo ""
echo "→ Generating key: $NAME"
echo "   Common Name: $CN"
echo ""

KEY="$OUT_DIR/$NAME.key"
CRT="$OUT_DIR/$NAME.crt"
DER="$OUT_DIR/$NAME.der"
PEM="$OUT_DIR/$NAME.pem"

# Create RSA-4096 key and a self-signed X.509 cert (10y)
openssl genrsa -out "$KEY" 4096
openssl req -new -x509 -key "$KEY" -sha256 -subj "/CN=$CN" -days 3650 -out "$CRT"
chmod 600 "$KEY"

# Also produce DER and combined PEM if useful
openssl x509 -in "$CRT" -outform DER -out "$DER"
cat "$KEY" "$CRT" > "$PEM"
chmod 600 "$PEM"

echo "═══════════════════════════════════════════════════════════════"
echo "✅ MOK key generated successfully!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "📁 Key files saved to: $OUT_DIR/"
echo ""
echo "   $NAME.key - Private key (KEEP SECRET!)"
echo "   $NAME.crt - Certificate (public, for verification)"
echo "   $NAME.der - DER format certificate"
echo "   $NAME.pem - Combined key+cert for convenience"
echo ""
echo "🔐 Certificate details:"
# Show details
openssl x509 -in "$CRT" -noout -subject -issuer -dates -fingerprint -sha1

# Create comprehensive README in MOK directory
cat > "$OUT_DIR/README.md" <<'MOKREADME'
# 🔑 MOK (Machine Owner Key) Directory

This directory contains your **MOK keys** for signing kernel modules so they work with SecureBoot enabled.

## 📚 What is MOK?

**MOK (Machine Owner Key)** is a key type for signing **kernel modules** (`.ko` files). When SecureBoot is enabled, the Linux kernel rejects unsigned kernel modules for security.

## 🚀 Quick Start

1. **Generate MOK key** (if not already done):
   ```bash
   ./pf.py secure-mok-new
   ```

2. **Enroll MOK**:
   ```bash
   ./pf.py os-mok-enroll
   # Set a password when prompted
   ```

3. **Reboot** - MOK Manager will appear to complete enrollment

4. **Sign modules**:
   ```bash
   ./sign-kernel-modules.sh /path/to/module.ko
   ```

## 🔍 Verify Enrollment

```bash
./pf.py os-mok-list-keys
mokutil --sb-state
```

## 📖 Full Documentation

See the main repository README.md for complete MOK documentation, common use cases, and troubleshooting.
MOKREADME

echo ""
echo "📚 What to do next:"
echo ""
echo "  1️⃣  Enroll this MOK on your system:"
echo "     ./pf.py os-mok-enroll"
echo "     (You'll be prompted to set a password - remember it!)"
echo ""
echo "  2️⃣  Reboot your system"
echo "     During boot, you'll see the MOK Manager - enter the password to enroll"
echo ""
echo "  3️⃣  Sign kernel modules with this MOK:"
echo "     ./sign-kernel-modules.sh /path/to/module.ko"
echo "     OR: MODULE_PATH=/lib/modules/\$(uname -r)/kernel/drivers/... ./pf.py os-kmod-sign"
echo ""
echo "💡 EXAMPLE: Sign the APFS driver (common use case):"
echo "     ./sign-kernel-modules.sh /lib/modules/\$(uname -r)/kernel/fs/apfs/apfs.ko"
echo ""
echo "  4️⃣  Check enrollment status anytime:"
echo "     ./pf.py os-mok-list-keys"
echo ""
echo "📖 For detailed MOK documentation, see:"
echo "   $OUT_DIR/README.md (just created!)"
echo ""