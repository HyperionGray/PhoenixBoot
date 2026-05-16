/*
 * PhoenixGuard Module Signature Verification Library
 * Part of the edk2-bootkit-defense project
 *
 * This is the installable public API for module signature verification.
 * Consumers load certificates once, verify one or more kernel modules, free
 * each returned result, and then call pg_cleanup() before process exit.
 */

#ifndef PGMODVERIFY_H
#define PGMODVERIFY_H

#include <time.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Verification result returned by pg_verify_module_signature().
 *
 * All pointer fields are heap allocated by the library and remain valid until
 * pg_free_verify_result() is called on the containing structure.
 */
typedef struct {
    int valid;                    /* 1 if signature is valid, 0 otherwise */
    int has_signature;           /* 1 if module has a signature, 0 otherwise */
    char *signer;               /* Fingerprint of signing certificate (malloc'd) */
    char *algorithm;            /* Signature algorithm used (malloc'd) */
    char *hash_algorithm;       /* Hash algorithm used (malloc'd) */
    char *error_message;        /* Error description if verification failed (malloc'd) */
    long signature_offset;      /* Offset of signature data in file */
    size_t signature_size;      /* Size of signature data in bytes */
    time_t verification_time;   /* Timestamp when verification was performed */
} pg_verify_result_t;

/*
 * Load PEM/DER certificates from a directory into the process-local verifier
 * cache.
 *
 * Call this once before verification. Returns the number of certificates
 * loaded. A return value of 0 means no usable certificates were loaded.
 */
int pg_load_certificates_from_dir(const char *cert_dir);

/*
 * Verify a single kernel module against the certificates previously loaded with
 * pg_load_certificates_from_dir().
 *
 * Returns an allocated result structure that must be released with
 * pg_free_verify_result(). Returns NULL only for critical failures such as
 * memory allocation or file access setup failures.
 */
pg_verify_result_t *pg_verify_module_signature(const char *module_path);

/*
 * Free a result returned by pg_verify_module_signature().
 *
 * Safe to call with NULL.
 */
void pg_free_verify_result(pg_verify_result_t *result);

/*
 * Release the certificate cache and other process-global library state.
 *
 * Call this once when verification work is complete.
 */
void pg_cleanup(void);

#ifdef __cplusplus
}
#endif

#endif /* PGMODVERIFY_H */
