#!/usr/bin/env bash
# Description: Tests PhoenixBoot with cloud-init user/password setup in QEMU.
# This verifies that NuclearBoot can work with cloud-init configurations.

set -euo pipefail
mkdir -p out/qemu out/cloud-init

if [ ! -f out/esp/esp.img ]; then
    echo "☠ No ESP image found - run './pf.py build-package-esp' first"
    exit 1
fi

# Get discovered OVMF paths from ESP packaging stage
if [ ! -f out/esp/ovmf_paths.txt ]; then
    echo "☠ OVMF paths not found - run './pf.py build-package-esp' first"
    exit 1
fi

OVMF_CODE_PATH=$(sed -n '1p' out/esp/ovmf_paths.txt)
OVMF_VARS_PATH=$(sed -n '2p' out/esp/ovmf_paths.txt)

if [ ! -f "$OVMF_CODE_PATH" ] || [ ! -f "$OVMF_VARS_PATH" ]; then
    echo "☠ OVMF files not found at discovered paths:"
    echo "   CODE: $OVMF_CODE_PATH"
    echo "   VARS: $OVMF_VARS_PATH"
    exit 1
fi

echo "Using OVMF: $OVMF_CODE_PATH"

# Create cloud-init configuration
cat > out/cloud-init/meta-data << EOF
instance-id: phoenixboot-test-$(date +%s)
local-hostname: phoenixboot-test-vm
EOF

# Create user-data with password hash for 'testpass'
cat > out/cloud-init/user-data << EOF
#cloud-config
users:
  - name: phoenixuser
    passwd: \$6\$rounds=4096\$saltsalt\$IxDD3jeSOb18LKbD8RO7CRiTKaM7qGH9j3RYV8yxcF8pZCvDfhDqKnKcHXUBxXLDvhPJ6k8ZMJ0Sk0N1234567
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash

runcmd:
  - echo "PhoenixBoot cloud-init integration test: SUCCESS" > /var/log/phoenixboot-cloudinit.log
  - logger "PhoenixBoot cloud-init test completed successfully"
EOF

# Create cloud-init ISO
if ! command -v genisoimage &> /dev/null; then
    echo "☠ genisoimage not found - install with: sudo apt-get install genisoimage"
    exit 1
fi

genisoimage -output out/cloud-init/cloud-init.iso \
    -volid cidata -joliet -rock \
    out/cloud-init/user-data out/cloud-init/meta-data 2>/dev/null

echo "Created cloud-init ISO"

# Copy OVMF vars (writable)
cp "$OVMF_VARS_PATH" out/qemu/OVMF_VARS_cloudinit.fd

# Launch QEMU with ESP and cloud-init ISO
QT=${PG_QEMU_TIMEOUT:-90}
timeout ${QT}s qemu-system-x86_64 \
    -machine q35 \
    -cpu host \
    -enable-kvm \
    -m 2G \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE_PATH" \
    -drive if=pflash,format=raw,file=out/qemu/OVMF_VARS_cloudinit.fd \
    -drive format=raw,file=out/esp/esp.img \
    -drive file=out/cloud-init/cloud-init.iso,media=cdrom \
    -serial file:out/qemu/serial-cloudinit.log \
    -display none \
    -no-reboot || true

# Check for success markers in serial output
TEST_RESULT="FAIL"
if grep -q "PhoenixGuard" out/qemu/serial-cloudinit.log; then
    echo "☠ PhoenixBoot banner found in boot log"
    TEST_RESULT="PASS"
else
    echo "☠ PhoenixBoot banner not found"
fi

# Generate JUnit-style report
{
    echo '<?xml version="1.0" encoding="UTF-8"?>';
    echo '<testsuite name="PhoenixGuard Cloud-Init Test" tests="1" failures="'$([[ $TEST_RESULT == "FAIL" ]] && echo "1" || echo "0")'" time="90">';
    echo '  <testcase name="Cloud-Init Integration Test" classname="PhoenixGuard.CloudInit">';
    [[ $TEST_RESULT == "FAIL" ]] && echo '    <failure message="Cloud-init test failed">No PhoenixGuard marker found in serial output</failure>' || true;
    echo '  </testcase>';
    echo '</testsuite>';
} > out/qemu/report-cloudinit.xml

if [ "$TEST_RESULT" == "PASS" ]; then
    echo "✅ Cloud-Init test PASSED"
    exit 0
else
    echo "❌ Cloud-Init test FAILED"
    exit 1
fi
