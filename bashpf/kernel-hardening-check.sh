#!/usr/bin/env bash
# Analyze kernel configuration against DISA STIG and hardening best practices
${PYTHON:-python3} utils/kernel_hardening_analyzer.py --auto
