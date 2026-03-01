#!/usr/bin/env bash
# Generate hardened kernel config (maximum security)
mkdir -p out/kernel-profiles
${PYTHON:-python3} utils/kernel_config_profiles.py --profile hardened --output out/kernel-profiles/hardened.config
echo "Profile generated: out/kernel-profiles/hardened.config"
