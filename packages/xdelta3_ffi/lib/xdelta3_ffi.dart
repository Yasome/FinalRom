import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const String _libName = 'xdelta3_ffi';

/// Opens the native xdelta3 dynamic library for the current platform.
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

typedef _XdeltaApplyNative = Int32 Function(
  Pointer<Utf8> patchPath,
  Pointer<Utf8> romPath,
  Pointer<Utf8> outputPath,
  Int32 ignoreChecksum,
);
typedef _XdeltaApplyDart = int Function(
  Pointer<Utf8> patchPath,
  Pointer<Utf8> romPath,
  Pointer<Utf8> outputPath,
  int ignoreChecksum,
);

final _XdeltaApplyDart _xdelta3Apply = _dylib
    .lookupFunction<_XdeltaApplyNative, _XdeltaApplyDart>('xdelta3_apply');

/// Result codes returned by the native xdelta3 wrapper. Values mirror the
/// `XDELTA3_FFI_*` constants in `src/xdelta3_ffi.h`. Other negative values are
/// xdelta3's own internal error codes.
class XdeltaResult {
  static const int ok = 0;
  static const int errOpenPatch = -5001;
  static const int errOpenRom = -5002;
  static const int errOpenOutput = -5003;
  static const int errWrongChecksum = -5010;

  /// The native library was built without the upstream xdelta3 sources.
  static const int errLibUnavailable = -6000;
}

/// Applies an xdelta3/VCDIFF patch ([patchPath]) to [romPath], writing the
/// result to [outputPath]. Returns a native result code (see [XdeltaResult]).
///
/// This is a synchronous, blocking call into native code; run it off the UI
/// isolate.
int xdelta3Apply(
  String patchPath,
  String romPath,
  String outputPath, {
  bool ignoreChecksum = false,
}) {
  final patchPtr = patchPath.toNativeUtf8();
  final romPtr = romPath.toNativeUtf8();
  final outputPtr = outputPath.toNativeUtf8();
  try {
    return _xdelta3Apply(patchPtr, romPtr, outputPtr, ignoreChecksum ? 1 : 0);
  } finally {
    malloc.free(patchPtr);
    malloc.free(romPtr);
    malloc.free(outputPtr);
  }
}
