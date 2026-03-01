#!/usr/bin/env bash
# Remove PhoenixGuard MOK certificate
bash -lc 'scripts/mok-management/unenroll-mok.sh "${MOK_CERT_DER:-out/keys/mok/PGMOK.der}"'
