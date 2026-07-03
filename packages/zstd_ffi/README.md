# zstd_ffi

FFI plugin that wraps the native [Zstandard](https://github.com/facebook/zstd)
(`libzstd`) **streaming** compression API, so large payloads (e.g. Switch NCA
content for the NSZ feature) can be compressed/decompressed in chunks without
buffering whole files in native code. Supports Android, iOS, Linux, macOS, and
Windows.

## Vendored libzstd sources

The upstream libzstd source tree **is vendored** under `src/zstd/` (see
[`src/zstd/PLACEHOLDER.md`](src/zstd/PLACEHOLDER.md) for provenance). The CMake
(Linux/Windows/Android) and Swift Package Manager (macOS) builds compile the real
libzstd from it, so the stream functions and the NSZ feature work.

If the sources are ever removed, the build falls back to a stub where those calls
return `ZSTD_FFI_ERR_LIB_UNAVAILABLE`.

## Usage

```dart
import 'package:zstd_ffi/zstd_ffi.dart';

final encoder = ZstdEncoder(level: 19);
try {
  final compressed = <int>[];
  compressed.addAll(encoder.process(chunk));      // feed chunks
  compressed.addAll(encoder.finish());            // flush + end
} finally {
  encoder.dispose();
}
```

The native calls are synchronous and blocking — run them off the UI isolate.
