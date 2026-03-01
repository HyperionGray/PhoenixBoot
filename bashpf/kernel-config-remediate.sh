#!/usr/bin/env bash
# Generate kernel config remediation script
mkdir -p out/remediation
${PYTHON:-python3} utils/kernel_config_remediation.py --current /boot/config-$(uname -r) --remediate --output out/remediation/kernel_remediation.sh
echo "Remediation script generated: out/remediation/kernel_remediation.sh"
