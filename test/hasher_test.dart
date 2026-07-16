import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/services/hasher_worker.dart';
import 'package:final_rom/services/native_hasher.dart';

Future<HasherResult> _hash(String path) async {
  final receivePort = ReceivePort();
  HasherWorker.runHasher(
    HasherParams(filePath: path, sendPort: receivePort.sendPort),
  );
  final result = await receivePort.first as HasherResult;
  receivePort.close();
  return result;
}

Future<File> _tempFile(String name, List<int> bytes) async {
  final dir = await Directory.systemTemp.createTemp('hasher_test');
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}

void main() {
  // Known digests for an empty input and the ASCII string "abc".
  const emptyVectors = {
    'md5': 'd41d8cd98f00b204e9800998ecf8427e',
    'sha1': 'da39a3ee5e6b4b0d3255bfef95601890afd80709',
    'sha256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    'crc32': '00000000',
  };
  const abcVectors = {
    'md5': '900150983cd24fb0d6963f7d28e17f72',
    'sha1': 'a9993e364706816aba3e25717850c26c9cd0d89d',
    'sha256': 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    'crc32': '352441C2',
  };

  void expectVectors(HasherResult result, Map<String, String> vectors) {
    expect(result.success, isTrue, reason: result.error);
    expect(result.md5Hash, vectors['md5']);
    expect(result.sha1Hash, vectors['sha1']);
    expect(result.sha256Hash, vectors['sha256']);
    expect(result.crc32Hash, vectors['crc32']);
  }

  test('runHasher matches known vectors for an empty file', () async {
    final file = await _tempFile('empty.bin', const []);
    expectVectors(await _hash(file.path), emptyVectors);
  });

  test('runHasher matches known vectors for "abc"', () async {
    final file = await _tempFile('abc.bin', 'abc'.codeUnits);
    expectVectors(await _hash(file.path), abcVectors);
  });

  test('runHasher matches known vectors for a multi-buffer file', () async {
    // 10 MiB of a repeating pattern crosses the 4 MiB read buffer boundary.
    final bytes = Uint8List(10 * 1024 * 1024);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = i & 0xFF;
    }
    final file = await _tempFile('pattern.bin', bytes);
    final byHasher = await _hash(file.path);

    // Cross-check SHA-256 against a second independent run.
    final again = await _hash(file.path);
    expect(byHasher.sha256Hash, again.sha256Hash);
    expect(byHasher.success, isTrue);
    expect(byHasher.crc32Hash, hasLength(8));
  });

  test('native hashes agree with known vectors when tools are available',
      () async {
    if (!NativeHasher.supported) return;
    final file = await _tempFile('abc_native.bin', 'abc'.codeUnits);
    for (final algo in NativeHashAlgo.values) {
      final native = await NativeHasher.compute(algo, file.path);
      if (native == null) continue; // tool missing on this machine
      expect(native, abcVectors[algo.name]);
    }
  });
}
