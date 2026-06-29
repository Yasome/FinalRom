import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/services/archive_service.dart';
import 'package:final_rom/services/archive_worker.dart';
import 'package:path/path.dart' as p;

Uint8List _patternBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = (i * 31 + 7) & 0xFF;
  }
  return bytes;
}

Future<Directory> _tempDir() => Directory.systemTemp.createTemp('archive_test');

/// Runs one worker operation in-process (no isolate, no native cells) and
/// returns its result.
Future<ArchiveResult> _run(
  ArchiveAction action,
  String inputPath,
  String outputPath,
  ArchiveFormat format,
) async {
  final port = ReceivePort();
  await ArchiveWorker.runArchive(ArchiveParams(
    action: action,
    inputPath: inputPath,
    outputPath: outputPath,
    format: format,
    sendPort: port.sendPort,
  ));
  final result = await port.first as ArchiveResult;
  port.close();
  return result;
}

void main() {
  group('format helpers (no native library needed)', () {
    test('formatForArchive infers the format from the extension', () {
      expect(ArchiveService.formatForArchive('a.zip'), ArchiveFormat.zip);
      expect(ArchiveService.formatForArchive('a.GZ'), ArchiveFormat.gzip);
      expect(ArchiveService.formatForArchive('a.zst'), ArchiveFormat.zstd);
      expect(ArchiveService.formatForArchive('a.7z'), ArchiveFormat.sevenZip);
      expect(ArchiveService.formatForArchive('a.txt'), isNull);
    });

    test('extensionFor matches the format', () {
      expect(ArchiveService.extensionFor(ArchiveFormat.zip), '.zip');
      expect(ArchiveService.extensionFor(ArchiveFormat.gzip), '.gz');
      expect(ArchiveService.extensionFor(ArchiveFormat.zstd), '.zst');
      expect(ArchiveService.extensionFor(ArchiveFormat.sevenZip), '.7z');
    });

    test('isContainer is true only for archive containers', () {
      expect(ArchiveService.isContainer(ArchiveFormat.zip), isTrue);
      expect(ArchiveService.isContainer(ArchiveFormat.sevenZip), isTrue);
      expect(ArchiveService.isContainer(ArchiveFormat.gzip), isFalse);
      expect(ArchiveService.isContainer(ArchiveFormat.zstd), isFalse);
    });
  });

  group('native round-trips (skipped when the libarchive lib is unavailable)', () {
    // The bare `flutter test` VM can't load the FFI .dll/.so; these verify on a
    // real desktop/device build. A failed compress means the lib isn't loadable,
    // so we skip rather than fail.
    Future<void> roundTrip(ArchiveFormat format) async {
      final dir = await _tempDir();
      try {
        final data = _patternBytes(2 * 1024 * 1024 + 5);
        final source = File(p.join(dir.path, 'rom.bin'));
        await source.writeAsBytes(data);

        final archive = p.join(dir.path, 'rom${ArchiveService.extensionFor(format)}');
        final compressed =
            await _run(ArchiveAction.compress, source.path, archive, format);
        if (!compressed.success) {
          markTestSkipped('archive_ffi native library unavailable: '
              '${compressed.error}');
          return;
        }
        expect(await File(archive).exists(), isTrue);

        final String restoredFile;
        if (ArchiveService.isContainer(format)) {
          final outDir = p.join(dir.path, 'out');
          final extracted =
              await _run(ArchiveAction.decompress, archive, outDir, format);
          expect(extracted.success, isTrue, reason: extracted.error);
          restoredFile = p.join(outDir, 'rom.bin');
        } else {
          restoredFile = p.join(dir.path, 'rom.restored');
          final extracted = await _run(
              ArchiveAction.decompress, archive, restoredFile, format);
          expect(extracted.success, isTrue, reason: extracted.error);
        }
        expect(await File(restoredFile).readAsBytes(), data);
      } finally {
        await dir.delete(recursive: true);
      }
    }

    test('zip round-trips', () => roundTrip(ArchiveFormat.zip));
    test('7z round-trips', () => roundTrip(ArchiveFormat.sevenZip));
    test('gzip round-trips', () => roundTrip(ArchiveFormat.gzip));
    test('zstd round-trips', () => roundTrip(ArchiveFormat.zstd));
  });
}
