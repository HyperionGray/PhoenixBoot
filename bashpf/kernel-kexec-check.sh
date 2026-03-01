#!/usr/bin/env bash
# Check if kexec is available for kernel remediation
${PYTHON:-python3} utils/kernel_config_remediation.py --check-kexec
