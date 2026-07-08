#ifndef MBEDTLS_FFI_H
#define MBEDTLS_FFI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

/* Result codes returned by the Mbed TLS wrapper. */
#define MBEDTLS_FFI_OK 0
#define MBEDTLS_FFI_ERR_INIT (-8001)
#define MBEDTLS_FFI_ERR_PARAM (-8002)
#define MBEDTLS_FFI_ERR_CRYPTO (-8003)

/* The native library was built without the vendored Mbed TLS sources. */
#define MBEDTLS_FFI_ERR_LIB_UNAVAILABLE (-6000)

/* Hash algorithm selectors for mbedtls_ffi_hash_create. */
#define MBEDTLS_FFI_HASH_MD5 1
#define MBEDTLS_FFI_HASH_SHA1 2
#define MBEDTLS_FFI_HASH_SHA256 3

/* Digest lengths in bytes for the algorithms above. */
#define MBEDTLS_FFI_MD5_LEN 16
#define MBEDTLS_FFI_SHA1_LEN 20
#define MBEDTLS_FFI_SHA256_LEN 32

/* ---- AES-128-CTR (streaming) ----
 *
 * CTR is a symmetric stream mode: the same operation both encrypts and
 * decrypts. A context holds the imported key plus a multipart cipher operation
 * whose counter/keystream state carries across process() calls, so callers can
 * feed arbitrary (including sub-block) chunk sizes and the keystream stays
 * aligned across chunk boundaries. */

/* Creates an AES-128-CTR context. key16 is the 16-byte AES key; counter16 is the
 * 16-byte initial counter block (used as the PSA IV). Returns an opaque handle,
 * or NULL on failure (bad params, library unavailable, or PSA error). */
FFI_PLUGIN_EXPORT void *mbedtls_ffi_aes_ctr_create(const uint8_t *key16,
                                                   const uint8_t *counter16);

/* Processes len bytes from in into out (out must have room for len bytes).
 * out may alias in. Returns MBEDTLS_FFI_OK on success. */
FFI_PLUGIN_EXPORT int mbedtls_ffi_aes_ctr_process(void *ctx,
                                                  const uint8_t *in,
                                                  uint8_t *out, size_t len);

/* Frees a context created by mbedtls_ffi_aes_ctr_create. */
FFI_PLUGIN_EXPORT void mbedtls_ffi_aes_ctr_free(void *ctx);

/* ---- Streaming hashes (MD5 / SHA-1 / SHA-256) ---- */

/* Creates a streaming hash context for the given MBEDTLS_FFI_HASH_* algorithm.
 * Returns an opaque handle, or NULL on failure. */
FFI_PLUGIN_EXPORT void *mbedtls_ffi_hash_create(int algo);

/* Feeds len bytes from in into the hash. Returns MBEDTLS_FFI_OK on success. */
FFI_PLUGIN_EXPORT int mbedtls_ffi_hash_update(void *ctx, const uint8_t *in,
                                              size_t len);

/* Finalizes the hash, writing the digest to out (cap must be >= the algorithm's
 * digest length) and reporting the number of bytes written in *written. The
 * context is finished but must still be released with mbedtls_ffi_hash_free.
 * Returns MBEDTLS_FFI_OK on success. */
FFI_PLUGIN_EXPORT int mbedtls_ffi_hash_finish(void *ctx, uint8_t *out,
                                              size_t cap, size_t *written);

/* Frees a context created by mbedtls_ffi_hash_create. */
FFI_PLUGIN_EXPORT void mbedtls_ffi_hash_free(void *ctx);

#ifdef __cplusplus
}
#endif

#endif /* MBEDTLS_FFI_H */
