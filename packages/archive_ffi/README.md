# archive_ffi

FFI bindings to [libarchive](https://www.libarchive.org/) for general-purpose
archive compression and extraction — zip, 7z, gzip, zstd, tar and more — used by
the app's Archive tab.

## How it works

A thin C-ABI wrapper (`src/archive_ffi.c`) exposes two blocking entry points:

- `archive_compress_ex(input, output, format, level, progress, cancel)`
- `archive_extract_ex(input, output, is_container, progress, cancel)`

Progress is reported as 0..1000 per-mille into a caller-allocated `int*`;
cancellation is cooperative via a second `int*` the caller sets to non-zero.
This mirrors the `chdman_ffi` contract, so the Dart side reuses the same
progress-cell / cancel-cell machinery. The Dart API is in `lib/archive_ffi.dart`
(`archiveCompress` / `archiveExtract`). All calls are blocking and must run off
the UI isolate.

## Vendored sources are not bundled

libarchive and its codec dependencies (zlib, liblzma, libzstd) are **not**
checked in. Until they are vendored, the plugin builds a **stub**: both functions
return `ARCHIVE_FFI_ERR_LIB_UNAVAILABLE` (-6000) and the app reports that archive
support is not built. The rest of the app is unaffected. See
`src/libarchive/PLACEHOLDER.md` for the vendoring layout and build wiring.

## Platforms

`android`, `ios`, `linux`, `macos`, `windows` — all as Flutter FFI plugins
(`ffiPlugin: true`). Desktop/Android build via `src/CMakeLists.txt`; Apple
platforms via the podspecs in `ios/` and `macos/`.
