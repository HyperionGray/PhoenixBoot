#!/usr/bin/env bash
# Compare current kernel config against hardened baseline
${PYTHON:-python3} utils/kernel_config_remediation.py --current /boot/config-$(uname -r) --diff
