/*
 * Thin C-ABI wrapper around Mbed TLS's PSA Crypto API so AES-128-CTR and the
 * MD5/SHA-1/SHA-256 digests can be driven from Dart via dart:ffi over
 * caller-owned buffers (NCAs are multi-GB, so nothing is buffered whole in
 * native code).
 *
 * The Mbed TLS sources are NOT bundled here. Vendor the official 4.2.0 release
 * tree into ./mbedtls as described in README.md. When present, the build
 * defines MBEDTLS_AVAILABLE and the real PSA implementation is compiled;
 * otherwise a stub is built that reports MBEDTLS_FFI_ERR_LIB_UNAVAILABLE so a
 * host build that omits the library (e.g. the iOS podspec) still links.
 *
 * Mbed TLS 4.x exposes crypto exclusively through PSA (psa_cipher_... / psa_hash_...);
 * the classic mbedtls_aes_... / mbedtls_md_... APIs are gone.
 */

#include "mbedtls_ffi.h"

#ifdef MBEDTLS_AVAILABLE

#include <stdlib.h>

#include "psa/crypto.h"

/* AES-CTR context: the imported (volatile) key plus a multipart cipher
 * operation whose counter/keystream state persists across process() calls. */
typedef struct {
  mbedtls_svc_key_id_t key;
  psa_cipher_operation_t op;
} aes_ctr_ctx;

/* psa_crypto_init is idempotent and, with MBEDTLS_THREADING_C enabled, safe to
 * call concurrently, so each create call re-asserts it rather than racing a
 * one-shot flag. create runs once per file/section, so the cost is negligible. */
static int ensure_psa_init(void) {
  return psa_crypto_init() == PSA_SUCCESS ? 0 : -1;
}

void *mbedtls_ffi_aes_ctr_create(const uint8_t *key16,
                                 const uint8_t *counter16) {
  if (key16 == NULL || counter16 == NULL) {
    return NULL;
  }
  if (ensure_psa_init() != 0) {
    return NULL;
  }

  aes_ctr_ctx *c = (aes_ctr_ctx *)calloc(1, sizeof(*c));
  if (c == NULL) {
    return NULL;
  }
  c->key = MBEDTLS_SVC_KEY_ID_INIT;
  c->op = psa_cipher_operation_init();

  psa_key_attributes_t attr = psa_key_attributes_init();
  psa_set_key_usage_flags(&attr, PSA_KEY_USAGE_ENCRYPT);
  psa_set_key_algorithm(&attr, PSA_ALG_CTR);
  psa_set_key_type(&attr, PSA_KEY_TYPE_AES);
  psa_set_key_bits(&attr, 128);

  psa_status_t st = psa_import_key(&attr, key16, 16, &c->key);
  if (st != PSA_SUCCESS) {
    free(c);
    return NULL;
  }

  /* CTR is symmetric, so the encrypt setup also decrypts. The 16-byte initial
   * counter block is supplied as the PSA IV. */
  st = psa_cipher_encrypt_setup(&c->op, c->key, PSA_ALG_CTR);
  if (st == PSA_SUCCESS) {
    st = psa_cipher_set_iv(&c->op, counter16, 16);
  }
  if (st != PSA_SUCCESS) {
    psa_cipher_abort(&c->op);
    psa_destroy_key(c->key);
    free(c);
    return NULL;
  }

  /* setup copied the key into the operation, so the key slot is no longer
   * needed. Release it now rather than holding it for the cipher's whole life:
   * PSA has a small fixed pool of key slots (default 32), and callers create a
   * fresh cipher per NCA section — hundreds over a file — relying on the
   * finalizer for cleanup, which would otherwise exhaust the pool. */
  psa_destroy_key(c->key);
  c->key = MBEDTLS_SVC_KEY_ID_INIT;

  return c;
}

int mbedtls_ffi_aes_ctr_process(void *ctx, const uint8_t *in, uint8_t *out,
                                size_t len) {
  aes_ctr_ctx *c = (aes_ctr_ctx *)ctx;
  if (c == NULL || (in == NULL && len != 0) || (out == NULL && len != 0)) {
    return MBEDTLS_FFI_ERR_PARAM;
  }
  if (len == 0) {
    return MBEDTLS_FFI_OK;
  }

  size_t produced = 0;
  psa_status_t st = psa_cipher_update(&c->op, in, len, out, len, &produced);
  if (st != PSA_SUCCESS) {
    return MBEDTLS_FFI_ERR_CRYPTO;
  }
  /* CTR is a 1:1 stream mode; update always emits exactly len bytes. A shorter
   * result would mean the mode buffered internally, breaking the counter carry
   * contract callers rely on. */
  if (produced != len) {
    return MBEDTLS_FFI_ERR_CRYPTO;
  }
  return MBEDTLS_FFI_OK;
}

void mbedtls_ffi_aes_ctr_free(void *ctx) {
  aes_ctr_ctx *c = (aes_ctr_ctx *)ctx;
  if (c == NULL) {
    return;
  }
  psa_cipher_abort(&c->op);
  psa_destroy_key(c->key);
  free(c);
}

void *mbedtls_ffi_hash_create(int algo) {
  psa_algorithm_t alg;
  switch (algo) {
    case MBEDTLS_FFI_HASH_MD5:
      alg = PSA_ALG_MD5;
      break;
    case MBEDTLS_FFI_HASH_SHA1:
      alg = PSA_ALG_SHA_1;
      break;
    case MBEDTLS_FFI_HASH_SHA256:
      alg = PSA_ALG_SHA_256;
      break;
    default:
      return NULL;
  }
  if (ensure_psa_init() != 0) {
    return NULL;
  }

  psa_hash_operation_t *op =
      (psa_hash_operation_t *)calloc(1, sizeof(*op));
  if (op == NULL) {
    return NULL;
  }
  *op = psa_hash_operation_init();
  if (psa_hash_setup(op, alg) != PSA_SUCCESS) {
    free(op);
    return NULL;
  }
  return op;
}

int mbedtls_ffi_hash_update(void *ctx, const uint8_t *in, size_t len) {
  psa_hash_operation_t *op = (psa_hash_operation_t *)ctx;
  if (op == NULL || (in == NULL && len != 0)) {
    return MBEDTLS_FFI_ERR_PARAM;
  }
  if (len == 0) {
    return MBEDTLS_FFI_OK;
  }
  return psa_hash_update(op, in, len) == PSA_SUCCESS ? MBEDTLS_FFI_OK
                                                     : MBEDTLS_FFI_ERR_CRYPTO;
}

int mbedtls_ffi_hash_finish(void *ctx, uint8_t *out, size_t cap,
                            size_t *written) {
  psa_hash_operation_t *op = (psa_hash_operation_t *)ctx;
  if (op == NULL || out == NULL) {
    return MBEDTLS_FFI_ERR_PARAM;
  }
  size_t w = 0;
  psa_status_t st = psa_hash_finish(op, out, cap, &w);
  if (st != PSA_SUCCESS) {
    return MBEDTLS_FFI_ERR_CRYPTO;
  }
  if (written != NULL) {
    *written = w;
  }
  return MBEDTLS_FFI_OK;
}

void mbedtls_ffi_hash_free(void *ctx) {
  psa_hash_operation_t *op = (psa_hash_operation_t *)ctx;
  if (op == NULL) {
    return;
  }
  psa_hash_abort(op);
  free(op);
}

#else /* !MBEDTLS_AVAILABLE */

void *mbedtls_ffi_aes_ctr_create(const uint8_t *key16,
                                 const uint8_t *counter16) {
  (void)key16;
  (void)counter16;
  return NULL;
}

int mbedtls_ffi_aes_ctr_process(void *ctx, const uint8_t *in, uint8_t *out,
                                size_t len) {
  (void)ctx;
  (void)in;
  (void)out;
  (void)len;
  return MBEDTLS_FFI_ERR_LIB_UNAVAILABLE;
}

void mbedtls_ffi_aes_ctr_free(void *ctx) { (void)ctx; }

void *mbedtls_ffi_hash_create(int algo) {
  (void)algo;
  return NULL;
}

int mbedtls_ffi_hash_update(void *ctx, const uint8_t *in, size_t len) {
  (void)ctx;
  (void)in;
  (void)len;
  return MBEDTLS_FFI_ERR_LIB_UNAVAILABLE;
}

int mbedtls_ffi_hash_finish(void *ctx, uint8_t *out, size_t cap,
                            size_t *written) {
  (void)ctx;
  (void)out;
  (void)cap;
  (void)written;
  return MBEDTLS_FFI_ERR_LIB_UNAVAILABLE;
}

void mbedtls_ffi_hash_free(void *ctx) { (void)ctx; }

#endif /* MBEDTLS_AVAILABLE */
