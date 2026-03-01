#!/usr/bin/env bash
# Generate permissive kernel config for BIOS flashing
mkdir -p out/kernel-profiles
${PYTHON:-python3} utils/kernel_config_profiles.py --profile permissive --output out/kernel-profiles/permissive.config
echo "Profile generated: out/kernel-profiles/permissive.config"
