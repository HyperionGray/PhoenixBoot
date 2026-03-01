#!/usr/bin/env bash
# Convert DER/PKCS#12 bundle into PEM cert and key (set DER_PATH, OUT_DIR, NAME)
bash -lc 'scripts/secure-boot/der-extract.sh "${DER_PATH:-}" "${OUT_DIR:-out/keys}" "${NAME:-PGMOK}"'
