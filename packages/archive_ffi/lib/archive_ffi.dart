import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const String _libName = 'archive_ffi';

/// Opens the native archive dynamic library for the current platform.
/// Throws (lazily, on first use) if the library cannot be loaded.
final DynamicLibrary _dylib = () {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    // The framework name depends on the dependency manager: Swift Package
    // Manager names it after the SPM product (dashes), CocoaPods after the pod
    // (underscores). Try the SPM name first, then fall back to CocoaPods.
    final String spmName = _libName.replaceAll('_', '-');
    try {
      return DynamicLibrary.open('$spmName.framework/$spmName');
    } on ArgumentError {
      return DynamicLibrary.open('$_libName.framework/$_libName');
    }
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}();

// ---- native typedefs ----

typedef _CompressNative = Int32 Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputPath,
  Int32 format,
  Int32 level,
  Pointer<Int32> progress,
  Pointer<Int32> cancel,
);
typedef _CompressDart = int Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputPath,
  int format,
  int level,
  Pointer<Int32> progress,
  Pointer<Int32> cancel,
);

typedef _ExtractNative = Int32 Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputPath,
  Int32 isContainer,
  Pointer<Int32> progress,
  Pointer<Int32> cancel,
);
typedef _ExtractDart = int Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputPath,
  int isContainer,
  Pointer<Int32> progress,
  Pointer<Int32> cancel,
);

final _CompressDart _compress = _dylib
    .lookupFunction<_CompressNative, _CompressDart>('archive_compress_ex');
final _ExtractDart _extract =
    _dylib.lookupFunction<_ExtractNative, _ExtractDart>('archive_extract_ex');

/// Format selectors mirroring the `ARCHIVE_FFI_FORMAT_*` constants in
/// `src/archive_ffi.h`.
class ArchiveFfiFormat {
  static const int zip = 0;
  static const int gzip = 1;
  static const int zstd = 2;
  static const int sevenZip = 3;
}

/// Result codes returned by the native wrapper. Values mirror the
/// `ARCHIVE_FFI_*` constants in `src/archive_ffi.h`.
class ArchiveFfiResult {
  static const int ok = 0;
  static const int errOpenInput = -7101;
  static const int errOpenOutput = -7102;
  static const int errFormat = -7103;
  static const int errInternal = -7106;
  static const int errCancelled = -7107;

  /// The native library was built without the vendored libarchive sources.
  static const int errLibUnavailable = -6000;
}

/// Compresses [inputPath] into [outputPath] using [format]
/// (an [ArchiveFfiFormat] value). [level] <= 0 selects the format default.
/// [progress] and [cancel] are native `Int32` cells the caller keeps alive for
/// the duration of the call. Returns an [ArchiveFfiResult] code. Blocking — call
/// off the UI isolate.
int archiveCompress({
  required String inputPath,
  required String outputPath,
  required int format,
  int level = 0,
  Pointer<Int32>? progress,
  Pointer<Int32>? cancel,
}) {
  final inputPtr = inputPath.toNativeUtf8();
  final outputPtr = outputPath.toNativeUtf8();
  try {
    return _compress(inputPtr, outputPtr, format, level, progress ?? nullptr,
        cancel ?? nullptr);
  } finally {
    malloc.free(inputPtr);
    malloc.free(outputPtr);
  }
}

/// Extracts [inputPath]. When [isContainer] is true (zip/7z/tar) entries are
/// written under the directory [outputPath]; otherwise the single decompressed
/// stream (gzip/zstd) is written to the file [outputPath]. Returns an
/// [ArchiveFfiResult] code. Blocking — call off the UI isolate.
int archiveExtract({
  required String inputPath,
  required String outputPath,
  required bool isContainer,
  Pointer<Int32>? progress,
  Pointer<Int32>? cancel,
}) {
  final inputPtr = inputPath.toNativeUtf8();
  final outputPtr = outputPath.toNativeUtf8();
  try {
    return _extract(inputPtr, outputPtr, isContainer ? 1 : 0,
        progress ?? nullptr, cancel ?? nullptr);
  } finally {
    malloc.free(inputPtr);
    malloc.free(outputPtr);
  }
}
