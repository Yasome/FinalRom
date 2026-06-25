import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/patcher/checksums.dart';
import 'package:final_rom/patcher/patcher.dart';
import 'package:final_rom/patcher/ips_patcher.dart';
import 'package:final_rom/patcher/bps_patcher.dart';
import 'package:final_rom/patcher/patcher_factory.dart';

/// BPS/UPS-style variable-length integer encoding (inverse of the patchers'
/// `decode()`), used to build a synthetic BPS patch in the test.
List<int> bpsEncode(int n) {
  final out = <int>[];
  while (true) {
    final x = n & 0x7f;
    n >>= 7;
    if (n == 0) {
      out.add(0x80 | x);
      break;
    }
    out.add(x);
    n -= 1;
  }
  return out;
}

void le32(List<int> out, int value) {
  out.add(value & 0xff);
  out.add((value >> 8) & 0xff);
  out.add((value >> 16) & 0xff);
  out.add((value >> 24) & 0xff);
}

Future<File> writeTemp(Directory dir, String name, List<int> bytes) async {
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('patcher_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CRC32', () {
    test('matches the known "123456789" vector', () {
      final data = '123456789'.codeUnits;
      expect(crc32Bytes(data), 0xCBF43926);
    });
  });

  group('IPS', () {
    test('applies a simple overwrite record and copies the ROM tail', () async {
      final source = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);

      // "PATCH" + record(offset=2, size=2, data=[0xAA,0xBB]) + "EOF"
      final patch = <int>[];
      patch.addAll('PATCH'.codeUnits);
      patch.addAll([0x00, 0x00, 0x02]); // offset 2 (3-byte BE)
      patch.addAll([0x00, 0x02]); // size 2 (2-byte BE)
      patch.addAll([0xAA, 0xBB]); // data
      patch.addAll('EOF'.codeUnits);

      final romFile = await writeTemp(tempDir, 'rom.bin', source);
      final patchFile = await writeTemp(tempDir, 'patch.ips', patch);
      final outFile = File('${tempDir.path}/out.bin');

      final report = await IpsPatcher(
        patchFile: patchFile,
        romFile: romFile,
        outputFile: outFile,
      ).apply();

      final result = await outFile.readAsBytes();
      expect(result, [0, 1, 0xAA, 0xBB, 4, 5, 6, 7]);

      // IPS has no embedded checksums, so the report carries no checks.
      expect(report.format, 'IPS');
      expect(report.checks, isEmpty);
    });
  });

  group('BPS', () {
    test('identity patch reproduces the source and validates checksums',
        () async {
      final source = Uint8List.fromList([10, 20, 30, 40]);

      final body = <int>[];
      body.addAll('BPS1'.codeUnits);
      body.addAll(bpsEncode(source.length)); // source size
      body.addAll(bpsEncode(source.length)); // target size
      body.addAll(bpsEncode(0)); // metadata size
      // One SOURCE_READ command covering the whole length.
      final command = ((source.length - 1) << 2) | 0; // mode 0
      body.addAll(bpsEncode(command));

      final sourceCrc = crc32Bytes(source);
      le32(body, sourceCrc); // source CRC
      le32(body, sourceCrc); // target CRC (identity == source)
      final patchCrc = crc32Bytes(body); // CRC over everything written so far
      le32(body, patchCrc); // patch CRC

      final romFile = await writeTemp(tempDir, 'rom.bin', source);
      final patchFile = await writeTemp(tempDir, 'patch.bps', body);
      final outFile = File('${tempDir.path}/out.bin');

      final report = await BpsPatcher(
        patchFile: patchFile,
        romFile: romFile,
        outputFile: outFile,
      ).apply();

      final result = await outFile.readAsBytes();
      expect(result, source);

      // Enforced checksums => three passed CRC32 checks (patch/source/output).
      expect(report.format, 'BPS');
      expect(report.checks.length, 3);
      expect(report.checks.every((check) => check.outcome == CheckOutcome.passed),
          isTrue);
    });

    test('identity patch with ignoreChecksum marks checks as skipped',
        () async {
      final source = Uint8List.fromList([10, 20, 30, 40]);

      final body = <int>[];
      body.addAll('BPS1'.codeUnits);
      body.addAll(bpsEncode(source.length));
      body.addAll(bpsEncode(source.length));
      body.addAll(bpsEncode(0));
      body.addAll(bpsEncode(((source.length - 1) << 2) | 0));
      final sourceCrc = crc32Bytes(source);
      le32(body, sourceCrc);
      le32(body, sourceCrc);
      le32(body, crc32Bytes(body));

      final romFile = await writeTemp(tempDir, 'rom.bin', source);
      final patchFile = await writeTemp(tempDir, 'patch.bps', body);
      final outFile = File('${tempDir.path}/out.bin');

      final report = await BpsPatcher(
        patchFile: patchFile,
        romFile: romFile,
        outputFile: outFile,
      ).apply(ignoreChecksum: true);

      expect(report.checks.every((check) => check.outcome == CheckOutcome.skipped),
          isTrue);
    });

    test('rejects an incompatible ROM when checksums are enforced', () async {
      final source = Uint8List.fromList([10, 20, 30, 40]);

      final body = <int>[];
      body.addAll('BPS1'.codeUnits);
      body.addAll(bpsEncode(source.length));
      body.addAll(bpsEncode(source.length));
      body.addAll(bpsEncode(0));
      body.addAll(bpsEncode(((source.length - 1) << 2) | 0));
      final sourceCrc = crc32Bytes(source);
      le32(body, sourceCrc);
      le32(body, sourceCrc);
      le32(body, crc32Bytes(body));

      // ROM that does not match the recorded source CRC.
      final wrongRom = await writeTemp(tempDir, 'rom.bin', [99, 99, 99, 99]);
      final patchFile = await writeTemp(tempDir, 'patch.bps', body);
      final outFile = File('${tempDir.path}/out.bin');

      expect(
        () => BpsPatcher(
          patchFile: patchFile,
          romFile: wrongRom,
          outputFile: outFile,
        ).apply(),
        throwsA(isA<PatchException>()),
      );
    });
  });

  group('PatcherFactory', () {
    test('recognises supported patch extensions', () {
      expect(PatcherFactory.isSupportedPatch('hack.ips'), isTrue);
      expect(PatcherFactory.isSupportedPatch('hack.xdelta'), isTrue);
      expect(PatcherFactory.isSupportedPatch('game.3ds'), isFalse);
    });

    test('formatName returns the detected format label or null', () {
      expect(PatcherFactory.formatName('hack.bps'), 'BPS');
      expect(PatcherFactory.formatName('hack.IPS32'), 'IPS32');
      expect(PatcherFactory.formatName('hack.vcdiff'), 'xdelta');
      expect(PatcherFactory.formatName('game.3ds'), isNull);
    });

    test('throws for unknown patch formats', () {
      expect(
        () => PatcherFactory.create(
          patchFile: File('x.zzz'),
          romFile: File('rom'),
          outputFile: File('out'),
        ),
        throwsA(isA<PatchException>()),
      );
    });
  });
}
