#!/usr/bin/env bash
# Full MOK workflow: generate keys, enroll MOK
./pf.py secure-mok-new
./pf.py os-mok-enroll
