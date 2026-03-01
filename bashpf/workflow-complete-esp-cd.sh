#!/usr/bin/env bash
# Complete workflow: Create artifacts, prepare CD, generate instructions
./pf.py workflow-artifact-create
./pf.py workflow-cd-prepare
./pf.py workflow-secureboot-instructions

echo ""
echo "✅ Complete ESP and CD workflow finished!"
echo "   Artifacts: out/artifacts/"
echo "   CD build:  nuclear-cd-build/"
echo "   Docs:      out/artifacts/docs/SECURE_BOOT_SETUP.md"
