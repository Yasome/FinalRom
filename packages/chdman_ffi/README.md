# chdman_ffi

FFI plugin that wraps MAME's CHD ("chdman") library so the app can **create**
and **extract** CD CHD images (`.cue`/`.bin`/`.gdi`/`.iso` ↔ `.chd`). Supports
Android, iOS, Linux, macOS, and Windows.

## Vendored MAME chd sources

The MAME chd library subset and its codec libraries (zlib, lzma, FLAC, zstd,
utf8proc) **are vendored** under `src/chd/` (see
[`src/chd/PLACEHOLDER.md`](src/chd/PLACEHOLDER.md) for provenance/layout). The
CMake (Linux/Windows/Android) and Swift Package Manager (macOS) builds compile the
real CHD backend from them, so `chdmanCreateCd` / `chdmanExtractCd` work.

If the sources are ever removed, the build falls back to a stub where those calls
return `ChdmanResult.errLibUnavailable`; the rest of the app is unaffected.

## Usage

```dart
import 'package:chdman_ffi/chdman_ffi.dart';

final code = chdmanCreateCd(inputCuePath, outputChdPath, force: false);
if (code != ChdmanResult.ok) {
  // handle error
}
```

The native calls are synchronous and blocking — run them off the UI isolate.
