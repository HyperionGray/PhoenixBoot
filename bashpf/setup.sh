#!/usr/bin/env bash
# Complete project setup: build + package + verify
./pf.py build-setup build-build build-package-esp
./pf.py verify-esp-robust
