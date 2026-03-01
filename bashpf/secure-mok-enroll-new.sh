#!/usr/bin/env bash
# Generate + enroll PhoenixGuard MOK (reboot to complete)
bash -lc 'scripts/mok-management/mok-new.sh "${NAME:-PGMOK}" "${CN:-PhoenixGuard Module Key}"'
bash -lc 'scripts/mok-management/enroll-mok.sh "out/keys/${NAME:-PGMOK}.crt" "out/keys/${NAME:-PGMOK}.der" ${MOK_DRY_RUN:-0}'
