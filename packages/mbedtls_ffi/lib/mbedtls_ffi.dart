import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const String _libName = 'mbedtls_ffi';

/// Opens the native Mbed TLS wrapper library for the current platform.
DynamicLibrary _open() {
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
}

// ---- native typedefs ----

typedef _AesCtrCreateNative = Pointer<Void> Function(
    Pointer<Uint8> key, Pointer<Uint8> counter);
typedef _AesCtrCreateDart = Pointer<Void> Function(
    Pointer<Uint8> key, Pointer<Uint8> counter);

typedef _AesCtrProcessNative = Int32 Function(
    Pointer<Void> ctx, Pointer<Uint8> input, Pointer<Uint8> output, Size len);
typedef _AesCtrProcessDart = int Function(
    Pointer<Void> ctx, Pointer<Uint8> input, Pointer<Uint8> output, int len);

typedef _HashCreateNative = Pointer<Void> Function(Int32 algo);
typedef _HashCreateDart = Pointer<Void> Function(int algo);

typedef _HashUpdateNative = Int32 Function(
    Pointer<Void> ctx, Pointer<Uint8> input, Size len);
typedef _HashUpdateDart = int Function(
    Pointer<Void> ctx, Pointer<Uint8> input, int len);

typedef _HashFinishNative = Int32 Function(
    Pointer<Void> ctx, Pointer<Uint8> output, Size cap, Pointer<Size> written);
typedef _HashFinishDart = int Function(
    Pointer<Void> ctx, Pointer<Uint8> output, int cap, Pointer<Size> written);

typedef _FreeNative = Void Function(Pointer<Void> ctx);
typedef _FreeDart = void Function(Pointer<Void> ctx);

/// Looked-up native entry points plus the finalizers that reclaim leaked
/// contexts. Constructed once, lazily; if the library or any symbol is missing
/// the construction throws and [mbedtlsFfiAvailable] reports false.
class _Bindings {
  final _AesCtrCreateDart aesCtrCreate;
  final _AesCtrProcessDart aesCtrProcess;
  final _FreeDart aesCtrFree;
  final _HashCreateDart hashCreate;
  final _HashUpdateDart hashUpdate;
  final _HashFinishDart hashFinish;
  final _FreeDart hashFree;
  final NativeFinalizer aesCtrFinalizer;
  final NativeFinalizer hashFinalizer;

  _Bindings(DynamicLibrary lib)
      : aesCtrCreate = lib.lookupFunction<_AesCtrCreateNative, _AesCtrCreateDart>(
            'mbedtls_ffi_aes_ctr_create'),
        aesCtrProcess =
            lib.lookupFunction<_AesCtrProcessNative, _AesCtrProcessDart>(
                'mbedtls_ffi_aes_ctr_process'),
        aesCtrFree = lib.lookupFunction<_FreeNative, _FreeDart>(
            'mbedtls_ffi_aes_ctr_free'),
        hashCreate = lib.lookupFunction<_HashCreateNative, _HashCreateDart>(
            'mbedtls_ffi_hash_create'),
        hashUpdate = lib.lookupFunction<_HashUpdateNative, _HashUpdateDart>(
            'mbedtls_ffi_hash_update'),
        hashFinish = lib.lookupFunction<_HashFinishNative, _HashFinishDart>(
            'mbedtls_ffi_hash_finish'),
        hashFree = lib.lookupFunction<_FreeNative, _FreeDart>(
            'mbedtls_ffi_hash_free'),
        aesCtrFinalizer = NativeFinalizer(
            lib.lookup<NativeFinalizerFunction>('mbedtls_ffi_aes_ctr_free')),
        hashFinalizer = NativeFinalizer(
            lib.lookup<NativeFinalizerFunction>('mbedtls_ffi_hash_free'));
}

final _Bindings? _bindings = () {
  try {
    return _Bindings(_open());
  } catch (_) {
    return null;
  }
}();

/// Whether the native Mbed TLS library loaded and exposes every entry point.
/// When false, callers should fall back to a pure-Dart implementation.
bool get mbedtlsFfiAvailable => _bindings != null;

/// Result codes returned by the native wrapper. Values mirror the
/// `MBEDTLS_FFI_*` constants in `src/mbedtls_ffi.h`.
class MbedTlsResult {
  static const int ok = 0;
  static const int errInit = -8001;
  static const int errParam = -8002;
  static const int errCrypto = -8003;

  /// The native library was built without the vendored Mbed TLS sources.
  static const int errLibUnavailable = -6000;
}

/// Thrown when the native Mbed TLS library reports an error or is unavailable.
class MbedTlsException implements Exception {
  final String message;
  final int code;
  MbedTlsException(this.message, this.code);
  @override
  String toString() => 'MbedTlsException($code): $message';
}

/// Streaming digest algorithms exposed by the wrapper. [id] matches the
/// `MBEDTLS_FFI_HASH_*` selector; [digestLength] is the output size in bytes.
enum HashAlgorithm {
  md5(1, 16),
  sha1(2, 20),
  sha256(3, 32);

  const HashAlgorithm(this.id, this.digestLength);
  final int id;
  final int digestLength;
}

/// AES-128-CTR context backed by a native PSA multipart cipher operation. CTR
/// is symmetric, so [process] both encrypts and decrypts; the counter/keystream
/// state carries across calls, so chunks may be any size (including sub-block).
/// Always [dispose] when done; a leaked instance is still reclaimed by a
/// [NativeFinalizer].
class NativeAesCtr implements Finalizable {
  Pointer<Void> _ctx;
  final _Bindings _b;
  bool _disposed = false;

  NativeAesCtr._(this._ctx, this._b) {
    _b.aesCtrFinalizer.attach(this, _ctx.cast(), detach: this);
  }

  /// Creates an AES-128-CTR context. [key] must be 16 bytes; [counter] is the
  /// 16-byte initial counter block.
  factory NativeAesCtr({required Uint8List key, required Uint8List counter}) {
    final b = _bindings;
    if (b == null) {
      throw MbedTlsException(
          'mbedtls_ffi native library unavailable', MbedTlsResult.errLibUnavailable);
    }
    if (key.length != 16) {
      throw ArgumentError('AES-128-CTR key must be 16 bytes, got ${key.length}');
    }
    if (counter.length != 16) {
      throw ArgumentError('CTR counter must be 16 bytes, got ${counter.length}');
    }
    final keyPtr = malloc<Uint8>(16);
    final ctrPtr = malloc<Uint8>(16);
    try {
      keyPtr.asTypedList(16).setAll(0, key);
      ctrPtr.asTypedList(16).setAll(0, counter);
      final ctx = b.aesCtrCreate(keyPtr, ctrPtr);
      if (ctx == nullptr) {
        throw MbedTlsException(
            'Failed to create AES-CTR context', MbedTlsResult.errCrypto);
      }
      return NativeAesCtr._(ctx, b);
    } finally {
      malloc.free(keyPtr);
      malloc.free(ctrPtr);
    }
  }

  /// Encrypts or decrypts [chunk], returning a same-length result.
  Uint8List process(Uint8List chunk) {
    if (_disposed) {
      throw StateError('NativeAesCtr already disposed');
    }
    if (chunk.isEmpty) {
      return Uint8List(0);
    }
    final len = chunk.length;
    final inPtr = malloc<Uint8>(len);
    final outPtr = malloc<Uint8>(len);
    try {
      inPtr.asTypedList(len).setAll(0, chunk);
      final rc = _b.aesCtrProcess(_ctx, inPtr, outPtr, len);
      if (rc != MbedTlsResult.ok) {
        throw MbedTlsException('AES-CTR process failed', rc);
      }
      return Uint8List.fromList(outPtr.asTypedList(len));
    } finally {
      malloc.free(inPtr);
      malloc.free(outPtr);
    }
  }

  /// Releases the native context. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _b.aesCtrFinalizer.detach(this);
    _b.aesCtrFree(_ctx);
    _ctx = nullptr;
  }
}

/// Streaming MD5 / SHA-1 / SHA-256 digest backed by a native PSA multipart hash
/// operation. Feed data with [update]; [finish] returns the digest and releases
/// the context. A leaked instance is reclaimed by a [NativeFinalizer].
class NativeHash implements Finalizable {
  Pointer<Void> _ctx;
  final _Bindings _b;
  final HashAlgorithm algorithm;
  bool _finished = false;

  NativeHash._(this._ctx, this._b, this.algorithm) {
    _b.hashFinalizer.attach(this, _ctx.cast(), detach: this);
  }

  factory NativeHash(HashAlgorithm algorithm) {
    final b = _bindings;
    if (b == null) {
      throw MbedTlsException(
          'mbedtls_ffi native library unavailable', MbedTlsResult.errLibUnavailable);
    }
    final ctx = b.hashCreate(algorithm.id);
    if (ctx == nullptr) {
      throw MbedTlsException(
          'Failed to create ${algorithm.name} context', MbedTlsResult.errCrypto);
    }
    return NativeHash._(ctx, b, algorithm);
  }

  factory NativeHash.md5() => NativeHash(HashAlgorithm.md5);
  factory NativeHash.sha1() => NativeHash(HashAlgorithm.sha1);
  factory NativeHash.sha256() => NativeHash(HashAlgorithm.sha256);

  /// Feeds [chunk] into the digest.
  void update(Uint8List chunk) {
    if (_finished) {
      throw StateError('NativeHash already finished');
    }
    if (chunk.isEmpty) return;
    final len = chunk.length;
    final inPtr = malloc<Uint8>(len);
    try {
      inPtr.asTypedList(len).setAll(0, chunk);
      final rc = _b.hashUpdate(_ctx, inPtr, len);
      if (rc != MbedTlsResult.ok) {
        throw MbedTlsException('hash update failed', rc);
      }
    } finally {
      malloc.free(inPtr);
    }
  }

  /// Finalizes the digest, releasing the native context. Call at most once.
  Uint8List finish() {
    if (_finished) {
      throw StateError('NativeHash already finished');
    }
    final cap = algorithm.digestLength;
    final outPtr = malloc<Uint8>(cap);
    final written = malloc<Size>();
    try {
      final rc = _b.hashFinish(_ctx, outPtr, cap, written);
      if (rc != MbedTlsResult.ok) {
        throw MbedTlsException('hash finish failed', rc);
      }
      final digest = Uint8List.fromList(outPtr.asTypedList(written.value));
      _release();
      return digest;
    } finally {
      malloc.free(outPtr);
      malloc.free(written);
    }
  }

  /// Releases the native context without finalizing (e.g. on an abandoned
  /// hash). Idempotent; [finish] calls this internally.
  void dispose() => _release();

  void _release() {
    if (_finished) return;
    _finished = true;
    _b.hashFinalizer.detach(this);
    _b.hashFree(_ctx);
    _ctx = nullptr;
  }
}
