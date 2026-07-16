# mbedtls_ffi

FFI plugin that wraps [Mbed TLS](https://github.com/Mbed-TLS/mbedtls) 4.2.0 via its
**PSA Crypto** API, exposing two hot native primitives to Dart:

- **AES-128-CTR** streaming cipher (`NativeAesCtr`) — replaces the pure-Dart CTR loop
  that bottlenecked NSZ (de)compression at ~11.6 MiB/s.
- **Streaming MD5 / SHA-1 / SHA-256** digests (`NativeHash`) — replaces the
  process-spawning (`certutil`/`md5sum`/`openssl dgst`) file-hashing path so all three
  digests are computed in a single read pass.

Supports Android, Linux, macOS, and Windows. iOS resolves to a stub podspec (not a
build target — repo precedent).

CRC32 is intentionally **not** part of this plugin; the app keeps its existing Dart
CRC32 table loop.

## Vendored Mbed TLS sources

The upstream Mbed TLS source tree **must be vendored** under `src/mbedtls/`. It is
obtained from the **official release tarball**, not the GitHub auto-generated archive:

```
https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-4.2.0/mbedtls-4.2.0.tar.bz2
```

Extract it so that `src/mbedtls/CMakeLists.txt`, `src/mbedtls/LICENSE`, and the bundled
`src/mbedtls/tf-psa-crypto/` subtree all exist. Mbed TLS 4.x moves the crypto core into
the **TF-PSA-Crypto** submodule; the release tarball bundles that subtree **and the
pre-generated PSA sources/headers**. The GitHub "Source code (tar.gz/zip)" auto-archive
omits the submodule and **cannot build** — do not use it.

The vendored tree is treated as read-only and is never edited. A trimmed PSA feature set
is supplied out-of-tree via [`src/crypto_config.h`](src/crypto_config.h) (AES + CTR,
MD5/SHA-1/SHA-256, threading, and AESNI/AESCE hardware acceleration only).

If the sources are missing the CMake build fails loudly (`FATAL_ERROR`); the C wrapper
also carries a compile-time stub branch returning `MBEDTLS_FFI_ERR_LIB_UNAVAILABLE` for
build configurations (e.g. the iOS podspec) that omit the library.

## Usage

```dart
import 'package:mbedtls_ffi/mbedtls_ffi.dart';

// AES-128-CTR, counter state carries across process() calls.
final cipher = NativeAesCtr(key: key16, counter: counter16);
try {
  final out = cipher.process(chunk);   // encrypt/decrypt (CTR is symmetric)
} finally {
  cipher.dispose();
}

// One read pass, three digests.
final md5 = NativeHash.md5();
final sha1 = NativeHash.sha1();
final sha256 = NativeHash.sha256();
for (final chunk in chunks) {
  md5.update(chunk);
  sha1.update(chunk);
  sha256.update(chunk);
}
final md5Digest = md5.finish();   // frees the context
```

The native calls are synchronous and blocking — run them off the UI isolate. Contexts are
also guarded by a `NativeFinalizer`, so a leaked handle is eventually reclaimed.
