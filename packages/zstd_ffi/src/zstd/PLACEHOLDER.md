> **STATUS (2026-07-03): the upstream Zstandard source tree IS now vendored and
> tracked here.** The note below is retained only as provenance. The CMake and
> Swift Package Manager builds compile the real libzstd from these files.

# Vendor the libzstd sources here

This directory contains the upstream Zstandard source tree.

Download a release from https://github.com/facebook/zstd and place it so the
layout is:

```
packages/zstd_ffi/src/zstd/lib/zstd.h
packages/zstd_ffi/src/zstd/lib/...           (the lib/ implementation)
packages/zstd_ffi/src/zstd/build/cmake/CMakeLists.txt
```

Once `zstd/lib/zstd.h` is present, the CMake build defines `ZSTD_AVAILABLE`,
builds libzstd as a static library (via `zstd/build/cmake`), and links it into
the wrapper. Until then `zstd_compress_stream` / `zstd_decompress_stream` return
`ZSTD_FFI_ERR_LIB_UNAVAILABLE` (-6000) and the NSZ feature reports that
Zstandard support is not built.

> Alternative: instead of vendoring, you may link a system/prebuilt libzstd by
> editing `../CMakeLists.txt` to `find_package(zstd)` and defining
> `ZSTD_AVAILABLE` accordingly.

> Darwin note: the iOS/macOS podspecs compile only the wrapper by default. To
> build real Zstandard support there, extend `ios/zstd_ffi.podspec` and
> `macos/zstd_ffi.podspec` to include the zstd `lib/` sources and define
> `ZSTD_AVAILABLE=1` (see the comments in those files).
