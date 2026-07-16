# Vendor the libarchive sources here

This directory must contain libarchive plus the codec libraries it depends on.
They are **not** bundled with the repo. Until they are present, the plugin builds
a stub (see `../archive_ffi.c`) and archive operations return
`ARCHIVE_FFI_ERR_LIB_UNAVAILABLE` (-6000).

## libarchive (from https://github.com/libarchive/libarchive)

Drop the libarchive source tree here so that this path exists:

```
packages/archive_ffi/src/libarchive/libarchive/archive.h
packages/archive_ffi/src/libarchive/libarchive/*.c
packages/archive_ffi/src/libarchive/CMakeLists.txt
```

The `src/CMakeLists.txt` enables the real backend the moment
`libarchive/libarchive/archive.h` exists.

## Codec libraries

libarchive needs these for the formats we use (zip/gzip → zlib; 7z/xz → liblzma;
zstd → libzstd). Vendor copies of the same sources the sibling plugins already
use, into:

```
packages/archive_ffi/src/zlib/    (from chdman_ffi's zlib)
packages/archive_ffi/src/zstd/    (lib/ subset, like chdman_ffi/zstd_ffi)
packages/archive_ffi/src/xz/      (liblzma, like xdelta3_ffi)
```

## Build wiring (added in Stage 2)

`src/CMakeLists.txt` will, when the sources are present:

1. Build each codec as a **uniquely-named** static lib (`archive_z`,
   `archive_zstd`, `archive_lzma`) — never via the upstream `add_subdirectory`,
   whose fixed target names (`zlibstatic`, ...) collide with `chdman_ffi` during
   Flutter's single-pass desktop plugin aggregation.
2. Expose them to libarchive's `find_package` via ALIAS targets
   (`ZLIB::ZLIB`, `LibLZMA::LibLZMA`, `zstd::libzstd`) + the `*_FOUND` vars, then
   `add_subdirectory(libarchive)` with features pared down
   (`ENABLE_OPENSSL/TEST/TAR/CPIO/CAT/INSTALL=OFF`, shared off).
3. Compile the codecs release-grade (`-O2 -DNDEBUG`) even in Debug — LZMA asserts
   dominate runtime — and apply the Android 16 KB page-size link flags.

## Darwin note

The iOS/macOS podspecs compile only the wrapper by default. To build the real
backend there, extend `ios/archive_ffi.podspec` and `macos/archive_ffi.podspec`
to include the vendored sources and define `ARCHIVE_FFI_HAVE_LIBARCHIVE=1`
(see the comments in those files).
