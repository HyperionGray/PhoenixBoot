#!/usr/bin/env bash
# Simplified UUEFI test script - creates minimal ESP and tests UUEFI boot

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "${SCRIPT_DIR}/../.."

echo "🧪 Testing UUEFI application..."

# Create directories
mkdir -p out/esp out/qemu

# Check if UUEFI.efi exists
UUEFI_SRC="staging/boot/UUEFI.efi"
if [ ! -f "$UUEFI_SRC" ]; then
    echo "❌ Missing $UUEFI_SRC"
    exit 1
fi

echo "✅ Found UUEFI.efi"

# Create minimal ESP image
IMG=out/esp/esp-uuefi-simple.img
echo "📦 Creating minimal ESP image with GPT..."

# Create a larger image to accommodate GPT
dd if=/dev/zero of="$IMG" bs=1M count=64 status=none

# Create GPT partition table and ESP partition
sgdisk -n 1:2048:0 -t 1:EF00 "$IMG" >/dev/null 2>&1

# Find the partition offset
OFFSET=$((2048 * 512))

# Create FAT32 filesystem on the partition
mkfs.fat -F32 -S 512 --offset $((2048)) "$IMG" >/dev/null 2>&1

# Copy UUEFI as BOOTX64.EFI
echo "📝 Installing UUEFI.efi as BOOTX64.EFI..."
mmd -i "$IMG" ::/EFI
mmd -i "$IMG" ::/EFI/BOOT
mcopy -i "$IMG" "$UUEFI_SRC" ::/EFI/BOOT/BOOTX64.EFI

# Find OVMF
echo "🔍 Finding OVMF firmware..."
OVMF_CODE=""
OVMF_VARS=""

for CODE_PATH in \
    /usr/share/OVMF/OVMF_CODE_4M.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /usr/share/qemu/OVMF_CODE.fd \
    /usr/share/ovmf/OVMF.fd; do
    if [ -f "$CODE_PATH" ]; then
        OVMF_CODE="$CODE_PATH"
        break
    fi
done

for VARS_PATH in \
    /usr/share/OVMF/OVMF_VARS_4M.fd \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/edk2/ovmf/OVMF_VARS.fd \
    /usr/share/qemu/OVMF_VARS.fd; do
    if [ -f "$VARS_PATH" ]; then
        OVMF_VARS="$VARS_PATH"
        break
    fi
done

if [ -z "$OVMF_CODE" ] || [ -z "$OVMF_VARS" ]; then
    echo "❌ OVMF firmware not found"
    echo "Install with: sudo apt-get install ovmf"
    exit 1
fi

echo "✅ Found OVMF at $OVMF_CODE"

# Create test-specific VARS
VARS=out/qemu/OVMF_VARS_uuefi_simple.fd
cp "$OVMF_VARS" "$VARS"

# Run QEMU test
LOG=out/qemu/serial-uuefi-simple.log
REPORT=out/qemu/report-uuefi-simple.xml

echo "🚀 Booting UUEFI in QEMU..."
rm -f "$LOG"

# Check if KVM is available
KVM_OPTS=""
if [ -e /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_OPTS="-enable-kvm -cpu host"
else
    KVM_OPTS="-cpu qemu64"
fi

# Run with a 3-second boot delay for removable media path to work
timeout 15s qemu-system-x86_64 \
    -M q35 \
    $KVM_OPTS \
    -m 512M \
    -global driver=cfi.pflash01,property=secure,value=off \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive format=raw,file="$IMG" \
    -net none \
    -serial file:"$LOG" \
    -display none \
    || true

# Check results
echo ""
echo "📊 Test Results:"
echo "================"

if [ ! -f "$LOG" ] || [ ! -s "$LOG" ]; then
    echo "❌ FAILED: No serial output produced"
    exit 1
fi

echo "✅ Serial output captured ($(wc -l < "$LOG") lines)"

# Check for UUEFI markers
if grep -q "\[UUEFI-START\]" "$LOG" && grep -q "\[UUEFI-COMPLETE\]" "$LOG"; then
    echo "✅ UUEFI executed successfully!"
    echo ""
    echo "=== UUEFI Output ==="
    cat "$LOG"
    echo "===================="
    echo ""
    echo "✅ TEST PASSED"
    
    # Generate JUnit report
    cat > "$REPORT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="UUEFI Simple Test" tests="1" failures="0" time="60">
  <testcase name="UUEFI Boot and Execution" classname="PhoenixGuard.UUEFI"/>
</testsuite>
EOF
    
    exit 0
else
    echo "❌ FAILED: UUEFI markers not found in output"
    echo ""
    echo "=== Serial Output ==="
    cat "$LOG"
    echo "====================="
    
    # Generate failure report
    cat > "$REPORT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="UUEFI Simple Test" tests="1" failures="1" time="60">
  <testcase name="UUEFI Boot and Execution" classname="PhoenixGuard.UUEFI">
    <failure message="UUEFI markers not found in serial output">Check $LOG for details</failure>
  </testcase>
</testsuite>
EOF
    
    exit 1
fi
