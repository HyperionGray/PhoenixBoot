#!/usr/bin/env bash
# List available kernel configuration profiles (permissive/hardened/balanced)
${PYTHON:-python3} utils/kernel_config_profiles.py --list
