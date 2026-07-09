import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:final_rom/io_tuning.dart';
import 'native_hasher.dart';

class HasherParams {
  final String filePath;
  final SendPort sendPort;

  HasherParams({required this.filePath, required this.sendPort});
}

class HasherResult {
  final bool success;
  final String? error;
  final String? md5Hash;
  final String? sha1Hash;
  final String? sha256Hash;
  final String? crc32Hash;

  HasherResult({
    required this.success,
    this.error,
    this.md5Hash,
    this.sha1Hash,
    this.sha256Hash,
    this.crc32Hash,
  });
}

final List<int> _crc32Table = _makeCrcTable();

class HasherWorker {
  static const int _readBufferSize = hashReadBufferSize;

  static Future<void> runHasher(HasherParams params) async {
    try {
      final result = NativeHasher.supported
          ? await _runWithNative(params.filePath)
          : await _runAllInDart(params.filePath);
      params.sendPort.send(result);
    } catch (e) {
      params.sendPort.send(HasherResult(success: false, error: e.toString()));
    }
  }

  /// Single read pass: feeds each chunk to the three native (Mbed TLS) digest
  /// contexts and, in the same loop, the unchanged CRC32 table computation. If
  /// the native path throws mid-stream, falls back to the pure-Dart hasher so a
  /// result is still produced.
  static Future<HasherResult> _runWithNative(String filePath) async {
    RandomAccessFile? file;
    NativeDigests? digests;
    try {
      file = await File(filePath).open(mode: FileMode.read);
      digests = NativeDigests(
        {NativeHashAlgo.md5, NativeHashAlgo.sha1, NativeHashAlgo.sha256},
      );

      var crc32Value = 0xFFFFFFFF;
      final buffer = Uint8List(_readBufferSize);

      while (true) {
        final read = await file.readInto(buffer);
        if (read <= 0) break;

        // The native update copies each chunk synchronously, so reusing the
        // buffer for the next read is safe.
        final chunk = read == buffer.length
            ? buffer
            : Uint8List.sublistView(buffer, 0, read);
        digests.update(chunk);

        // CRC32: unchanged Dart table loop, folded into the same read pass.
        for (var i = 0; i < read; i++) {
          crc32Value =
              _crc32Table[(crc32Value ^ buffer[i]) & 0xFF] ^ (crc32Value >>> 8);
        }
      }

      final native = digests.finish();
      digests = null;
      crc32Value ^= 0xFFFFFFFF;
      final crc32Hash =
          crc32Value.toRadixString(16).padLeft(8, '0').toUpperCase();

      return HasherResult(
        success: true,
        md5Hash: native[NativeHashAlgo.md5],
        sha1Hash: native[NativeHashAlgo.sha1],
        sha256Hash: native[NativeHashAlgo.sha256],
        crc32Hash: crc32Hash,
      );
    } catch (_) {
      // Native hashing failed mid-stream; fall back to the pure-Dart path.
      return _runAllInDart(filePath);
    } finally {
      digests?.dispose();
      await file?.close();
    }
  }

  static Future<HasherResult> _runAllInDart(String filePath) async {
    final hashes = await _hashInDart(
      filePath,
      md5: true,
      sha1: true,
      sha256: true,
      crc32: true,
    );
    return HasherResult(
      success: true,
      md5Hash: hashes.md5,
      sha1Hash: hashes.sha1,
      sha256Hash: hashes.sha256,
      crc32Hash: hashes.crc32,
    );
  }

  static Future<_DartHashes> _hashInDart(
    String filePath, {
    bool md5 = false,
    bool sha1 = false,
    bool sha256 = false,
    bool crc32 = false,
  }) async {
    RandomAccessFile? file;
    try {
      file = await File(filePath).open(mode: FileMode.read);

      final md5Output = md5 ? AccumulatorSink<crypto.Digest>() : null;
      final sha1Output = sha1 ? AccumulatorSink<crypto.Digest>() : null;
      final sha256Output = sha256 ? AccumulatorSink<crypto.Digest>() : null;

      final md5Input = md5Output == null
          ? null
          : crypto.md5.startChunkedConversion(md5Output);
      final sha1Input = sha1Output == null
          ? null
          : crypto.sha1.startChunkedConversion(sha1Output);
      final sha256Input = sha256Output == null
          ? null
          : crypto.sha256.startChunkedConversion(sha256Output);

      var crc32Value = 0xFFFFFFFF;
      final buffer = Uint8List(_readBufferSize);

      while (true) {
        final read = await file.readInto(buffer);
        if (read <= 0) break;

        // Each hash consumes the slice synchronously, so reusing the buffer for
        // the next read is safe.
        final chunk = read == buffer.length
            ? buffer
            : Uint8List.sublistView(buffer, 0, read);
        md5Input?.add(chunk);
        sha1Input?.add(chunk);
        sha256Input?.add(chunk);

        if (crc32) {
          for (var i = 0; i < read; i++) {
            crc32Value =
                _crc32Table[(crc32Value ^ buffer[i]) & 0xFF] ^ (crc32Value >>> 8);
          }
        }
      }

      md5Input?.close();
      sha1Input?.close();
      sha256Input?.close();

      String? crc32Hash;
      if (crc32) {
        crc32Value ^= 0xFFFFFFFF;
        crc32Hash = crc32Value.toRadixString(16).padLeft(8, '0').toUpperCase();
      }

      return _DartHashes(
        md5: md5Output?.events.single.toString(),
        sha1: sha1Output?.events.single.toString(),
        sha256: sha256Output?.events.single.toString(),
        crc32: crc32Hash,
      );
    } finally {
      await file?.close();
    }
  }
}

class _DartHashes {
  final String? md5;
  final String? sha1;
  final String? sha256;
  final String? crc32;

  _DartHashes({this.md5, this.sha1, this.sha256, this.crc32});
}

List<int> _makeCrcTable() {
  final table = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    var c = i;
    for (var j = 0; j < 8; j++) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >>> 1);
      } else {
        c = c >>> 1;
      }
    }
    table[i] = c;
  }
  return table;
}

class AccumulatorSink<T> implements Sink<T> {
  final List<T> events = [];
  bool isClosed = false;

  @override
  void add(T event) {
    events.add(event);
  }

  @override
  void close() {
    isClosed = true;
  }
}
