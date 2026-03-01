#!/usr/bin/env bash
# Enroll PhoenixGuard MOK certificate
bash -lc 'scripts/mok-management/enroll-mok.sh "${MOK_CERT_PEM:-out/keys/mok/PGMOK.crt}" "${MOK_CERT_DER:-out/keys/mok/PGMOK.der}" ${MOK_DRY_RUN:-0}'
