#!/usr/bin/env bash
# Generate detailed kernel hardening report (text and JSON)
mkdir -p out/reports
${PYTHON:-python3} utils/kernel_hardening_analyzer.py --auto --format text --output out/reports/kernel_hardening_report.txt
${PYTHON:-python3} utils/kernel_hardening_analyzer.py --auto --format json --output out/reports/kernel_hardening_report.json
echo "Reports saved to:"
echo "  Text: out/reports/kernel_hardening_report.txt"
echo "  JSON: out/reports/kernel_hardening_report.json"
