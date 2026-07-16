import 'dart:io';
import 'dart:typed_data';

import 'package:final_rom/io_tuning.dart';
import 'package:mbedtls_ffi/mbedtls_ffi.dart';

enum NativeHashAlgo { md5, sha1, sha256 }

extension on NativeHashAlgo {
  HashAlgorithm get native {
    switch (this) {
      case NativeHashAlgo.md5:
        return HashAlgorithm.md5;
      case NativeHashAlgo.sha1:
        return HashAlgorithm.sha1;
      case NativeHashAlgo.sha256:
        return HashAlgorithm.sha256;
    }
  }
}

String _toHex(Uint8List bytes) {
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Streaming multi-algorithm digest backed by native Mbed TLS (PSA) hashes.
///
/// Create it with the algorithms you want, feed every file chunk to [update]
/// exactly once, then call [finish] to get the lowercase-hex digests. This lets
/// a single read pass serve MD5/SHA-1/SHA-256 at once (see [HasherWorker]).
/// Native contexts are released by [finish] (or [dispose] if abandoned).
class NativeDigests {
  final Map<NativeHashAlgo, NativeHash> _hashes;
  bool _done = false;

  NativeDigests._(this._hashes);

  factory NativeDigests(Set<NativeHashAlgo> algos) {
    final map = <NativeHashAlgo, NativeHash>{};
    try {
      for (final algo in algos) {
        map[algo] = NativeHash(algo.native);
      }
    } catch (_) {
      for (final h in map.values) {
        h.dispose();
      }
      rethrow;
    }
    return NativeDigests._(map);
  }

  void update(Uint8List chunk) {
    for (final h in _hashes.values) {
      h.update(chunk);
    }
  }

  Map<NativeHashAlgo, String> finish() {
    _done = true;
    return {
      for (final e in _hashes.entries) e.key: _toHex(e.value.finish()),
    };
  }

  void dispose() {
    if (_done) return;
    _done = true;
    for (final h in _hashes.values) {
      h.dispose();
    }
  }
}

/// Native file hashing over the Mbed TLS (PSA) FFI. Replaces the previous
/// desktop-only path that spawned `md5sum`/`openssl`/`certutil`; now works on
/// every platform where the native library loads (mobile included).
class NativeHasher {
  /// True when the native Mbed TLS library is loadable. When false, callers
  /// fall back to the pure-Dart `package:crypto` implementation.
  static bool get supported => mbedtlsFfiAvailable;

  /// Streams [filePath] through a single native digest and returns its
  /// lowercase-hex value, or null if hashing is unsupported or fails.
  static Future<String?> compute(NativeHashAlgo algo, String filePath) async {
    if (!supported) return null;
    RandomAccessFile? file;
    NativeHash? hash;
    try {
      file = await File(filePath).open(mode: FileMode.read);
      hash = NativeHash(algo.native);
      final buffer = Uint8List(hashReadBufferSize);
      while (true) {
        final read = await file.readInto(buffer);
        if (read <= 0) break;
        hash.update(read == buffer.length
            ? buffer
            : Uint8List.sublistView(buffer, 0, read));
      }
      final digest = _toHex(hash.finish());
      hash = null;
      return digest;
    } catch (_) {
      hash?.dispose();
      return null;
    } finally {
      await file?.close();
    }
  }
}
