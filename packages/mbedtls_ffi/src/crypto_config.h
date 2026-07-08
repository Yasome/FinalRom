/*
 * Trimmed TF-PSA-Crypto configuration for mbedtls_ffi.
 *
 * This is a FULL REPLACEMENT for the upstream default
 * tf-psa-crypto/include/psa/crypto_config.h, selected via the
 * TF_PSA_CRYPTO_CONFIG_FILE compile definition wired in src/CMakeLists.txt.
 * Modelled on the upstream configs/crypto-config-symmetric-only.h example but
 * pared down to only the mechanisms mbedtls_ffi uses:
 *
 *   - AES-128-CTR   (NSZ hot path)
 *   - MD5, SHA-1, SHA-256 digests (file hashing)
 *
 * Everything asymmetric (RSA/ECC/DH), every AEAD/MAC/KDF, and every other hash
 * is intentionally left out to shrink the static crypto library.
 */

#ifndef PSA_CRYPTO_CONFIG_H
#define PSA_CRYPTO_CONFIG_H

/* Opt into the config-format compatibility handling for this TF-PSA-Crypto
 * release (matches the upstream default's version symbol). */
#define TF_PSA_CRYPTO_CONFIG_VERSION 0x01000000

/*
 * SECTION: cryptographic mechanisms (PSA API)
 */

/* AES-CTR: the only cipher the wrapper drives. */
#define PSA_WANT_KEY_TYPE_AES                   1
#define PSA_WANT_ALG_CTR                        1

/* Digests computed in the single-pass file hasher. */
#define PSA_WANT_ALG_MD5                        1
#define PSA_WANT_ALG_SHA_1                      1
#define PSA_WANT_ALG_SHA_256                    1

/*
 * SECTION: infrastructure
 */

/* PSA crypto core. */
#define MBEDTLS_PSA_CRYPTO_C

/* Platform abstraction (calloc/free, etc.). */
#define MBEDTLS_PLATFORM_C

/* The PSA core still needs a DRBG selected, even though this wrapper never
 * generates keys or IVs (keys are imported, the CTR IV is caller-supplied) —
 * psa_crypto_random_impl.h fails to compile without one. CTR_DRBG is AES-based,
 * so it reuses code already compiled for the cipher. TF-PSA-Crypto 1.0 removed
 * the classic entropy module (MBEDTLS_ENTROPY_C) and the DRBG tuning macros;
 * the core now sources entropy internally, so only the module selector remains.
 * The DRBG still needs a seed source: MBEDTLS_PSA_BUILTIN_GET_ENTROPY pulls in
 * the platform OS RNG (getrandom/urandom on Unix, CryptGenRandom on Windows). */
#define MBEDTLS_CTR_DRBG_C
#define MBEDTLS_PSA_BUILTIN_GET_ENTROPY

/* Hardware AES acceleration. Both are safe to define unconditionally: each is
 * gated internally by the target architecture (AESNI on x86-64, AESCE on
 * ARMv8), so the wrong-arch one compiles to nothing. */
#define MBEDTLS_HAVE_ASM
#define MBEDTLS_AESNI_C
#define MBEDTLS_AESCE_C

/* Thread safety: multiple Dart isolates load this one shared library and share
 * PSA's global key store, so its internal locking must be enabled. PTHREAD is
 * available on Android/Linux/macOS; Windows needs THREADING_ALT instead and is
 * handled when that build target is wired up (its build runs in CI). */
#if !defined(_WIN32)
#define MBEDTLS_THREADING_C
#define MBEDTLS_THREADING_PTHREAD
#endif

#endif /* PSA_CRYPTO_CONFIG_H */
