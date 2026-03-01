#!/usr/bin/env bash
# Generate hardened kernel config baseline based on DISA STIG
mkdir -p out/baselines
${PYTHON:-python3} utils/kernel_hardening_analyzer.py --generate-baseline --output out/baselines/hardened_kernel.config
