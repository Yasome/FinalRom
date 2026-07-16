# xdelta3_ffi

FFI plugin that wraps the native [xdelta3](https://github.com/jmacd/xdelta)
(VCDIFF) library so the app can apply `.xdelta` / `.xdelta3` / `.vcdiff` ROM
patches. Supports Android, Windows, Linux, and macOS. LZMA secondary
compression (`-S lzma`) is available on every platform, including macOS (built
via Swift Package Manager).

## Vendored sources

The upstream xdelta3 sources (v3.1.1, Apache-2.0) are vendored under
`src/xdelta/`, and liblzma (xz, v5.4.6) under `src/xz/` for `-S lzma` secondary
compression. Both DJW and LZMA secondary compression are enabled, and liblzma is
linked statically into the plugin DLL. See
[`src/xdelta/PLACEHOLDER.md`](src/xdelta/PLACEHOLDER.md) for the file list,
configuration, and how to update.

If the `src/xdelta/` sources are ever removed, the plugin falls back to a stub:
`xdelta3Apply` returns `XdeltaResult.errLibUnavailable` and the app reports that
xdelta support is not built. The rest of the patcher formats are unaffected.

## Usage

```dart
import 'package:xdelta3_ffi/xdelta3_ffi.dart';

final code = xdelta3Apply(patchPath, romPath, outputPath, ignoreChecksum: false);
if (code != XdeltaResult.ok) {
  // handle error
}
```
