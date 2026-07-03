> **STATUS (2026-07-03): these sources ARE now vendored and tracked in this
> directory.** The instructions below are retained only as provenance for where
> the subset came from and how it is laid out. The CMake and Swift Package Manager
> builds compile the real CHD backend from these files; nothing needs to be added.

# Vendor the MAME chd sources here

This directory must contain a minimal subset of MAME's CHD library plus the
codec libraries the CD hunk codecs depend on.

## MAME chd subset (from https://github.com/mamedev/mame, `src/lib/util/`)

Drop these (and the `util`/`osd` support headers they `#include`) directly here:

- `chd.cpp` / `chd.h`
- `chdcodec.cpp` / `chdcodec.h`
- `cdrom.cpp` / `cdrom.h`
- `chdcd.cpp` / `chdcd.h`
- `hashing.cpp` / `hashing.h`
- support headers: `coretmpl.h`, `corefile.*`, `strformat.*`, `ioprocs.*`,
  `endianness.h`, `osdcomm.h`, and anything else the above pull in.

Layout:

```
packages/chdman_ffi/src/chd/chd.cpp
packages/chdman_ffi/src/chd/chd.h
...
```

## Codec libraries (static-lib subprojects)

The CD codecs need these built as static libs that expose the `z`, `lzma`,
`FLAC`, and `zstd` CMake targets:

```
packages/chdman_ffi/src/chd/third_party/zlib/CMakeLists.txt   -> target: z
packages/chdman_ffi/src/chd/third_party/lzma/CMakeLists.txt   -> target: lzma
packages/chdman_ffi/src/chd/third_party/flac/CMakeLists.txt   -> target: FLAC
packages/chdman_ffi/src/chd/third_party/zstd/CMakeLists.txt   -> target: zstd
```

(zlib → CDZL, lzma/7-Zip SDK → CDLZ, libFLAC → CDFL, zstd → CDZS, the last
needed to read modern CHDs on extract.)

## What happens until then

Once `chd/chd.cpp` and `chd/chd.h` are present, the CMake build defines
`CHDMAN_AVAILABLE` and compiles real CD support. Until then `chdman_create_cd`
and `chdman_extract_cd` return `CHDMAN_FFI_ERR_LIB_UNAVAILABLE` (-6000) and the
app reports that CHD support is not built. The rest of the app is unaffected.

After vendoring, also reconcile the create/extract bodies in
`../chdman_ffi.cpp` against the `do_createcd` / `do_extractcd` flow of the
MAME revision you vendored (see the `#warning` there).

> Darwin note: the iOS/macOS podspecs compile only the wrapper by default. To
> build real CHD support there, extend `ios/chdman_ffi.podspec` and
> `macos/chdman_ffi.podspec` to include `../src/chd/**/*` and define
> `CHDMAN_AVAILABLE=1` (see the comments in those files).
