import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const String _libName = 'chdman_ffi';

/// Opens the native chdman dynamic library for the current platform.
/// Throws (lazily, on first use) if the library cannot be loaded.
final DynamicLibrary _dylib = () {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}();

/// Mirrors the C `chdman_options` struct in `src/chdman_ffi.h`. Field order and
/// types must stay in sync with the native definition.
final class _ChdmanOptionsNative extends Struct {
  external Pointer<Utf8> codecs;
  @Int32()
  external int numProcessors;
  @Int32()
  external int hunkBytes;
  @Int32()
  external int force;
}

typedef _ChdmanCreateCdExNative = Int32 Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputChdPath,
  Pointer<_ChdmanOptionsNative> options,
  Pointer<Int32> progressPermille,
  Pointer<Int32> cancelFlag,
);
typedef _ChdmanCreateCdExDart = int Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputChdPath,
  Pointer<_ChdmanOptionsNative> options,
  Pointer<Int32> progressPermille,
  Pointer<Int32> cancelFlag,
);

typedef _ChdmanCreateDvdExNative = Int32 Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputChdPath,
  Pointer<_ChdmanOptionsNative> options,
  Pointer<Int32> progressPermille,
  Pointer<Int32> cancelFlag,
);
typedef _ChdmanCreateDvdExDart = int Function(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputChdPath,
  Pointer<_ChdmanOptionsNative> options,
  Pointer<Int32> progressPermille,
  Pointer<Int32> cancelFlag,
);

typedef _ChdmanExtractCdExNative = Int32 Function(
  Pointer<Utf8> inputChdPath,
  Pointer<Utf8> outputCuePath,
  Pointer<Utf8> outputBinPath,
  Pointer<_ChdmanOptionsNative> options,
  Pointer<Int32> progressPermille,
  Pointer<Int32> cancelFlag,
);
typedef _ChdmanExtractCdExDart = int Function(
  Pointer<Utf8> inputChdPath,
  Pointer<Utf8> outputCuePath,
  Pointer<Utf8> outputBinPath,
  Pointer<_ChdmanOptionsNative> options,
  Pointer<Int32> progressPermille,
  Pointer<Int32> cancelFlag,
);

typedef _ChdmanLastErrorNative = Pointer<Utf8> Function();
typedef _ChdmanLastErrorDart = Pointer<Utf8> Function();

final _ChdmanCreateCdExDart _chdmanCreateCdEx = _dylib
    .lookupFunction<_ChdmanCreateCdExNative, _ChdmanCreateCdExDart>(
        'chdman_create_cd_ex');

final _ChdmanCreateDvdExDart _chdmanCreateDvdEx = _dylib
    .lookupFunction<_ChdmanCreateDvdExNative, _ChdmanCreateDvdExDart>(
        'chdman_create_dvd_ex');

final _ChdmanExtractCdExDart _chdmanExtractCdEx = _dylib
    .lookupFunction<_ChdmanExtractCdExNative, _ChdmanExtractCdExDart>(
        'chdman_extract_cd_ex');

final _ChdmanLastErrorDart _chdmanLastError = _dylib
    .lookupFunction<_ChdmanLastErrorNative, _ChdmanLastErrorDart>(
        'chdman_last_error');

/// Tunable chdman options, mirroring the relevant command-line flags. Plain
/// data so it can be sent across isolates; converted to the native struct at
/// the FFI boundary.
class ChdOptions {
  /// Comma-separated CD codec tokens for create (`cdlz,cdzl,cdfl,cdzs,none`).
  /// null or empty selects the chdman default `cdlz,cdzl,cdfl`. Ignored by
  /// extract.
  final String? codecs;

  /// Max CPU threads chdman may use (`-np`). 0 means all processors.
  final int numProcessors;

  /// CHD hunk size in bytes for create (`-hs`). 0 means the chdman default.
  final int hunkBytes;

  /// Overwrite existing output files instead of failing.
  final bool force;

  const ChdOptions({
    this.codecs,
    this.numProcessors = 0,
    this.hunkBytes = 0,
    this.force = false,
  });
}

/// Result codes returned by the native chdman wrapper. Values mirror the
/// `CHDMAN_FFI_*` constants in `src/chdman_ffi.h`.
class ChdmanResult {
  static const int ok = 0;
  static const int errOpenInput = -7001;
  static const int errOpenOutput = -7002;
  static const int errInvalidInput = -7003;
  static const int errOutputExists = -7004;
  static const int errCodec = -7005;
  static const int errInternal = -7006;
  static const int errCancelled = -7007;

  /// The native library was built without the vendored MAME chd sources.
  static const int errLibUnavailable = -6000;
}

/// Allocates a native [_ChdmanOptionsNative] from [options]. The returned
/// pointer and the codecs string it references must both be freed by the
/// caller via [_freeOptions].
Pointer<_ChdmanOptionsNative> _allocOptions(ChdOptions options) {
  final optionsPtr = calloc<_ChdmanOptionsNative>();
  final hasCodecs = options.codecs != null && options.codecs!.isNotEmpty;
  optionsPtr.ref
    ..codecs = hasCodecs ? options.codecs!.toNativeUtf8() : nullptr
    ..numProcessors = options.numProcessors
    ..hunkBytes = options.hunkBytes
    ..force = options.force ? 1 : 0;
  return optionsPtr;
}

void _freeOptions(Pointer<_ChdmanOptionsNative> optionsPtr) {
  if (optionsPtr.ref.codecs != nullptr) malloc.free(optionsPtr.ref.codecs);
  calloc.free(optionsPtr);
}

/// Creates a CD CHD at [outputChdPath] from the CD image at [inputPath]
/// (`.cue`/`.gdi`/`.toc`/`.iso`). Returns a native result code (see
/// [ChdmanResult]).
///
/// When [progress] is non-null, native code writes 0..1000 (per-mille complete)
/// into it as work proceeds; read it concurrently from another isolate, since
/// this call blocks. Run off the UI isolate.
int chdmanCreateCd(
  String inputPath,
  String outputChdPath, {
  ChdOptions options = const ChdOptions(),
  Pointer<Int32>? progress,
  Pointer<Int32>? cancel,
}) {
  final inputPtr = inputPath.toNativeUtf8();
  final outputPtr = outputChdPath.toNativeUtf8();
  final optionsPtr = _allocOptions(options);
  try {
    return _chdmanCreateCdEx(
        inputPtr, outputPtr, optionsPtr, progress ?? nullptr, cancel ?? nullptr);
  } finally {
    malloc.free(inputPtr);
    malloc.free(outputPtr);
    _freeOptions(optionsPtr);
  }
}

/// Creates a DVD CHD at [outputChdPath] from the raw DVD image at [inputPath]
/// (`.iso`). The input is treated as a flat stream of 2048-byte logical sectors,
/// so its size must be a multiple of 2048. [ChdOptions.codecs] takes the general
/// codec tokens (`lzma`/`zlib`/`huff`/`flac`/`zstd`/`none`); null/empty (or a CD
/// token) selects the createdvd default `lzma,zlib,huff,flac`. Returns a native
/// result code (see [ChdmanResult]).
///
/// See [chdmanCreateCd] for the [progress]/[cancel] contract. Run off the UI
/// isolate.
int chdmanCreateDvd(
  String inputPath,
  String outputChdPath, {
  ChdOptions options = const ChdOptions(),
  Pointer<Int32>? progress,
  Pointer<Int32>? cancel,
}) {
  final inputPtr = inputPath.toNativeUtf8();
  final outputPtr = outputChdPath.toNativeUtf8();
  final optionsPtr = _allocOptions(options);
  try {
    return _chdmanCreateDvdEx(
        inputPtr, outputPtr, optionsPtr, progress ?? nullptr, cancel ?? nullptr);
  } finally {
    malloc.free(inputPtr);
    malloc.free(outputPtr);
    _freeOptions(optionsPtr);
  }
}

/// Extracts the CD CHD at [inputChdPath] into a `.cue` ([outputCuePath]) and
/// `.bin` ([outputBinPath]) pair. Only [ChdOptions.force] is used. See
/// [chdmanCreateCd] for the [progress] contract. Run off the UI isolate.
int chdmanExtractCd(
  String inputChdPath,
  String outputCuePath,
  String outputBinPath, {
  ChdOptions options = const ChdOptions(),
  Pointer<Int32>? progress,
  Pointer<Int32>? cancel,
}) {
  final inputPtr = inputChdPath.toNativeUtf8();
  final cuePtr = outputCuePath.toNativeUtf8();
  final binPtr = outputBinPath.toNativeUtf8();
  final optionsPtr = _allocOptions(options);
  try {
    return _chdmanExtractCdEx(
        inputPtr, cuePtr, binPtr, optionsPtr, progress ?? nullptr, cancel ?? nullptr);
  } finally {
    malloc.free(inputPtr);
    malloc.free(cuePtr);
    malloc.free(binPtr);
    _freeOptions(optionsPtr);
  }
}

/// The native detail for the most recent failed chdman call on the current
/// thread, or an empty string if none. Call this immediately after a non-ok
/// result from [chdmanCreateCd]/[chdmanCreateDvd]/[chdmanExtractCd] on the same
/// isolate to enrich the generic [ChdmanResult] code with the real reason.
String chdmanLastError() {
  final ptr = _chdmanLastError();
  return ptr == nullptr ? '' : ptr.toDartString();
}
