#!/usr/bin/env bash
# Generate new PhoenixGuard MOK keypair (use NAME and CN env)
bash -lc 'scripts/mok-management/mok-new.sh "${NAME:-PGMOK}" "${CN:-PhoenixGuard Module Key}"'
