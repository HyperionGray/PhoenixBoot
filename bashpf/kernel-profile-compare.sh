#!/usr/bin/env bash
# Compare current kernel config with profile (set PROFILE=permissive/hardened/balanced)
[ -n "${PROFILE:-}" ] || { echo "Usage: PROFILE=<profile> ./pf.py kernel-profile-compare"; exit 1; }
${PYTHON:-python3} utils/kernel_config_profiles.py --profile "${PROFILE}" --compare /boot/config-$(uname -r)
