#!/usr/bin/env bash
# Verify MOK certificate details
bash -lc 'scripts/mok-management/mok-verify.sh "${MOK_CERT_PEM:-out/keys/mok/PGMOK.crt}" "${MOK_CERT_DER:-out/keys/mok/PGMOK.der}"'
