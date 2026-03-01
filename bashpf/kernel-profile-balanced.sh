#!/usr/bin/env bash
# Generate balanced kernel config (security + flexibility)
mkdir -p out/kernel-profiles
${PYTHON:-python3} utils/kernel_config_profiles.py --profile balanced --output out/kernel-profiles/balanced.config
echo "Profile generated: out/kernel-profiles/balanced.config"
