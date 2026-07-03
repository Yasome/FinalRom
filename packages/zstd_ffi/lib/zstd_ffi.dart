import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const String _libName = 'zstd_ffi';

/// Opens the native zstd dynamic library for the current platform.
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

typedef _CctxCreateNative = Pointer<Void> Function(Int32 level, Int32 workers);
typedef _CctxCreateDart = Pointer<Void> Function(int level, int workers);

typedef _CtxFreeNative = Void Function(Pointer<Void> ctx);
typedef _CtxFreeDart = void Function(Pointer<Void> ctx);

typedef _DctxCreateNative = Pointer<Void> Function();
typedef _DctxCreateDart = Pointer<Void> Function();

typedef _CompressStreamNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> inPtr,
  Size inLen,
  Pointer<Size> inConsumed,
  Pointer<Uint8> outPtr,
  Size outCap,
  Pointer<Size> outProduced,
  Int32 finish,
  Pointer<Int32> finished,
);
typedef _CompressStreamDart = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> inPtr,
  int inLen,
  Pointer<Size> inConsumed,
  Pointer<Uint8> outPtr,
  int outCap,
  Pointer<Size> outProduced,
  int finish,
  Pointer<Int32> finished,
);

typedef _DecompressStreamNative = Int32 Function(
  Pointer<Void> ctx,
  Pointer<Uint8> inPtr,
  Size inLen,
  Pointer<Size> inConsumed,
  Pointer<Uint8> outPtr,
  Size outCap,
  Pointer<Size> outProduced,
  Pointer<Int32> finished,
);
typedef _DecompressStreamDart = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> inPtr,
  int inLen,
  Pointer<Size> inConsumed,
  Pointer<Uint8> outPtr,
  int outCap,
  Pointer<Size> outProduced,
  Pointer<Int32> finished,
);

typedef _SizeQueryNative = Size Function();
typedef _SizeQueryDart = int Function();

final _CctxCreateDart _cctxCreate =
    _dylib.lookupFunction<_CctxCreateNative, _CctxCreateDart>('zstd_cctx_create');
final _CtxFreeDart _cctxFree =
    _dylib.lookupFunction<_CtxFreeNative, _CtxFreeDart>('zstd_cctx_free');
final _DctxCreateDart _dctxCreate =
    _dylib.lookupFunction<_DctxCreateNative, _DctxCreateDart>('zstd_dctx_create');
final _CtxFreeDart _dctxFree =
    _dylib.lookupFunction<_CtxFreeNative, _CtxFreeDart>('zstd_dctx_free');
final _CompressStreamDart _compressStream =
    _dylib.lookupFunction<_CompressStreamNative, _CompressStreamDart>(
        'zstd_compress_stream');
final _DecompressStreamDart _decompressStream =
    _dylib.lookupFunction<_DecompressStreamNative, _DecompressStreamDart>(
        'zstd_decompress_stream');
final _SizeQueryDart _cstreamOutSize =
    _dylib.lookupFunction<_SizeQueryNative, _SizeQueryDart>('zstd_cstream_out_size');
final _SizeQueryDart _dstreamOutSize =
    _dylib.lookupFunction<_SizeQueryNative, _SizeQueryDart>('zstd_dstream_out_size');

/// Result codes returned by the native zstd wrapper. Values mirror the
/// `ZSTD_FFI_*` constants in `src/zstd_ffi.h`.
class ZstdResult {
  static const int ok = 0;
  static const int errInit = -8001;
  static const int errParam = -8002;
  static const int errStream = -8003;

  /// The native library was built without the vendored libzstd sources.
  static const int errLibUnavailable = -6000;
}

/// Thrown when the native zstd library reports an error or is unavailable.
class ZstdException implements Exception {
  final String message;
  final int code;
  ZstdException(this.message, this.code);
  @override
  String toString() => 'ZstdException($code): $message';
}

const int _fallbackOutSize = 128 * 1024;

/// Upper bound on consecutive zero-progress finish calls before we conclude the
/// stream is genuinely stalled (rather than just waiting on a zstd worker).
const int _maxIdleFinishCalls = 100000;

/// Streaming Zstandard compressor. Feed input through [process] and finish with
/// [finish]; always call [dispose] to release native resources.
class ZstdEncoder {
  Pointer<Void> _ctx;
  final int _outCapacity;
  bool _disposed = false;

  ZstdEncoder._(this._ctx, this._outCapacity);

  /// Creates a streaming compressor. [workers] sets the number of zstd worker
  /// threads (ZSTD_c_nbWorkers); when null it defaults to a value derived from
  /// the CPU count and capped to keep multi-threaded memory use bounded on
  /// phones. Pass 0 to force single-threaded.
  factory ZstdEncoder({int level = 19, int? workers}) {
    final workerCount = workers ?? defaultWorkerCount;
    final ctx = _cctxCreate(level, workerCount);
    if (ctx == nullptr) {
      throw ZstdException(
          'Failed to create zstd compression context (library unavailable?)',
          ZstdResult.errLibUnavailable);
    }
    final hinted = _cstreamOutSize();
    final outCapacity = hinted > 0 ? hinted : _fallbackOutSize;
    return ZstdEncoder._(ctx, outCapacity);
  }

  /// Default zstd worker-thread count. On mobile (Android/iOS), it is capped
  /// at 4 so the extra per-worker buffers at high compression levels stay
  /// within a mobile memory budget. On desktop, we leave 2 cores free to 
  /// prevent the UI thread from starving. Never less than 1.
  static final int defaultWorkerCount = () {
    final cores = Platform.numberOfProcessors;
    if (Platform.isAndroid || Platform.isIOS) {
      return math.max(1, math.min(cores, 4));
    }
    return math.max(1, cores - 2);
  }();

  /// Compresses [chunk], returning whatever compressed bytes are ready. May
  /// return an empty list while zstd buffers internally.
  Uint8List process(Uint8List chunk) => _run(chunk, finish: false);

  /// Flushes and finalizes the stream, returning the trailing compressed bytes.
  Uint8List finish() => _run(Uint8List(0), finish: true);

  Uint8List _run(Uint8List chunk, {required bool finish}) {
    if (_disposed) {
      throw StateError('ZstdEncoder already disposed');
    }
    return _pump(
      ctx: _ctx,
      input: chunk,
      outCapacity: _outCapacity,
      finish: finish,
      call: (ctx, inPtr, inLen, inConsumed, outPtr, outCap, outProduced,
              finished) =>
          _compressStream(ctx, inPtr, inLen, inConsumed, outPtr, outCap,
              outProduced, finish ? 1 : 0, finished),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cctxFree(_ctx);
    _ctx = nullptr;
  }
}

/// Streaming Zstandard decompressor. Feed input through [process]; always call
/// [dispose] to release native resources.
class ZstdDecoder {
  Pointer<Void> _ctx;
  final int _outCapacity;
  bool _disposed = false;

  ZstdDecoder._(this._ctx, this._outCapacity);

  factory ZstdDecoder() {
    final ctx = _dctxCreate();
    if (ctx == nullptr) {
      throw ZstdException(
          'Failed to create zstd decompression context (library unavailable?)',
          ZstdResult.errLibUnavailable);
    }
    final hinted = _dstreamOutSize();
    final outCapacity = hinted > 0 ? hinted : _fallbackOutSize;
    return ZstdDecoder._(ctx, outCapacity);
  }

  /// Decompresses [chunk], returning whatever plaintext bytes are ready.
  Uint8List process(Uint8List chunk) {
    if (_disposed) {
      throw StateError('ZstdDecoder already disposed');
    }
    return _pump(
      ctx: _ctx,
      input: chunk,
      outCapacity: _outCapacity,
      finish: false,
      call: (ctx, inPtr, inLen, inConsumed, outPtr, outCap, outProduced,
              finished) =>
          _decompressStream(ctx, inPtr, inLen, inConsumed, outPtr, outCap,
              outProduced, finished),
    );
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _dctxFree(_ctx);
    _ctx = nullptr;
  }
}

typedef _StreamCall = int Function(
  Pointer<Void> ctx,
  Pointer<Uint8> inPtr,
  int inLen,
  Pointer<Size> inConsumed,
  Pointer<Uint8> outPtr,
  int outCap,
  Pointer<Size> outProduced,
  Pointer<Int32> finished,
);

/// Shared loop that drives a single native stream call over [input], copying
/// the input into a native buffer and draining all available output. Handles
/// the "keep calling until input is consumed and (when finishing) the stream
/// reports done" contract of the zstd streaming API.
Uint8List _pump({
  required Pointer<Void> ctx,
  required Uint8List input,
  required int outCapacity,
  required bool finish,
  required _StreamCall call,
}) {
  final inPtr = input.isEmpty ? nullptr : malloc<Uint8>(input.length);
  final outPtr = malloc<Uint8>(outCapacity);
  final inConsumed = malloc<Size>();
  final outProduced = malloc<Size>();
  final finished = malloc<Int32>();
  final collected = BytesBuilder(copy: false);

  try {
    if (input.isNotEmpty) {
      inPtr.asTypedList(input.length).setAll(0, input);
    }

    int offset = 0;
    // Guards against a true spin while tolerating the transient zero-progress
    // calls that multi-threaded zstd can return while background jobs finish
    // flushing during ZSTD_e_end.
    var idleFinishCalls = 0;
    while (true) {
      final remaining = input.length - offset;
      final chunkPtr =
          remaining > 0 ? (inPtr + offset) : nullptr.cast<Uint8>();

      final code = call(ctx, chunkPtr, remaining, inConsumed, outPtr,
          outCapacity, outProduced, finished);
      if (code != ZstdResult.ok) {
        throw ZstdException('zstd stream call failed', code);
      }

      final produced = outProduced.value;
      if (produced > 0) {
        collected.add(Uint8List.fromList(outPtr.asTypedList(produced)));
      }
      final consumed = inConsumed.value;
      offset += consumed;

      final allInputConsumed = offset >= input.length;
      // Keep looping while output keeps filling the buffer (more to drain), or
      // while finishing until the stream signals completion.
      final outputSaturated = produced == outCapacity;
      if (finish) {
        if (finished.value == 1) break;
        // With workers, a finish call may legitimately consume nothing and
        // produce nothing while it waits on a worker thread; only treat a long
        // run of such calls as a genuine stall.
        if (produced == 0 && consumed == 0) {
          if (++idleFinishCalls > _maxIdleFinishCalls) {
            throw ZstdException(
                'zstd finish made no progress', ZstdResult.errStream);
          }
        } else {
          idleFinishCalls = 0;
        }
      } else {
        if (allInputConsumed && !outputSaturated) break;
      }
    }

    return collected.toBytes();
  } finally {
    if (inPtr != nullptr) malloc.free(inPtr);
    malloc.free(outPtr);
    malloc.free(inConsumed);
    malloc.free(outProduced);
    malloc.free(finished);
  }
}
