import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/switch/pfs0.dart';

void main() {
  group('PFS0 round-trip', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pfs0_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('builds and reads back members with correct content', () async {
      final alpha = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final beta = Uint8List.fromList(List.generate(4096, (i) => (i * 7) % 256));

      final builder = Pfs0Builder()
        ..add(Pfs0Member.fromBytes('alpha.nca', alpha))
        ..add(Pfs0Member.fromBytes('beta.tik', beta));

      final outPath = '${tempDir.path}/test.nsp';
      await builder.writeTo(outPath);

      final reader = await Pfs0Reader.open(outPath);
      try {
        expect(reader.entries.map((e) => e.name).toList(),
            ['alpha.nca', 'beta.tik']);
        expect(reader.entries[0].dataSize, alpha.length);
        expect(reader.entries[1].dataSize, beta.length);

        final readAlpha = await reader.readEntry(reader.entries[0]);
        final readBeta = await reader.readEntry(reader.entries[1]);
        expect(readAlpha, equals(alpha));
        expect(readBeta, equals(beta));
      } finally {
        await reader.close();
      }
    });

    test('streams a file-backed member from an offset', () async {
      // A source file whose interesting bytes start partway in, to exercise
      // Pfs0Member.fromFile's sourceOffset path (used to copy NCAs straight out
      // of an existing NSP without buffering).
      final source = File('${tempDir.path}/source.bin');
      final prefix = Uint8List.fromList(List.filled(64, 0xAA));
      final payload = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      await source.writeAsBytes([...prefix, ...payload]);

      final builder = Pfs0Builder()
        ..add(Pfs0Member.fromFile(
          'content.nca',
          source.path,
          size: payload.length,
          sourceOffset: prefix.length,
        ));

      final outPath = '${tempDir.path}/streamed.nsp';
      await builder.writeTo(outPath);

      final reader = await Pfs0Reader.open(outPath);
      try {
        final read = await reader.readEntry(reader.entries.single);
        expect(read, equals(payload));
      } finally {
        await reader.close();
      }
    });

    test('streams file members across many reused-buffer chunks', () async {
      // A small chunkSize that does not divide the payload evenly forces many
      // iterations through the single reused copy buffer, including a final
      // partial chunk (take < buffer.length) — the case most likely to break
      // when switching from read() to readInto()/writeFrom(buf, 0, n).
      final firstSource = File('${tempDir.path}/first.bin');
      final secondSource = File('${tempDir.path}/second.bin');
      final firstPayload =
          Uint8List.fromList(List.generate(10000, (i) => (i * 13) % 256));
      final secondPayload =
          Uint8List.fromList(List.generate(7777, (i) => (i * 31 + 5) % 256));
      await firstSource.writeAsBytes(firstPayload);
      await secondSource.writeAsBytes(secondPayload);

      final builder = Pfs0Builder()
        ..add(Pfs0Member.fromFile('first.nca', firstSource.path,
            size: firstPayload.length))
        ..add(Pfs0Member.fromBytes('inline.tik',
            Uint8List.fromList(List.filled(33, 0x5A))))
        ..add(Pfs0Member.fromFile('second.nca', secondSource.path,
            size: secondPayload.length));

      final outPath = '${tempDir.path}/multichunk.nsp';
      // 1024-byte buffer reused across ~18 read iterations and three members.
      await builder.writeTo(outPath, chunkSize: 1024);

      final reader = await Pfs0Reader.open(outPath);
      try {
        expect(reader.entries.map((e) => e.name).toList(),
            ['first.nca', 'inline.tik', 'second.nca']);
        expect(await reader.readEntry(reader.entries[0]), equals(firstPayload));
        expect(await reader.readEntry(reader.entries[2]), equals(secondPayload));
      } finally {
        await reader.close();
      }
    });
  });
}
