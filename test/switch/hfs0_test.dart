import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/switch/hfs0.dart';

void main() {
  group('HFS0 round-trip', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hfs0_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('builds and reads back HFS0 structure with correct content', () async {
      final file = await File('${tempDir.path}/test.hfs0').open(mode: FileMode.write);
      final builder = Hfs0Builder(file: file, startOffset: 0, headerReservedSize: 0x8000);
      await builder.begin();

      final file1Data = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final file2Data = Uint8List.fromList(List.generate(4096, (i) => (i * 7) % 256));

      await builder.addFile('file1.nca', file1Data.length);
      await file.writeFrom(file1Data);
      await builder.finalizeFileWrite('file1.nca');

      await builder.addFile('file2.tik', file2Data.length);
      await file.writeFrom(file2Data);
      await builder.finalizeFileWrite('file2.tik');

      await builder.end();
      await file.close();

      // Read back
      final readFile = await File('${tempDir.path}/test.hfs0').open(mode: FileMode.read);
      final reader = Hfs0Reader(readFile, 0);
      try {
        await reader.initialize();
        expect(reader.header.entries.map((e) => e.name).toList(), ['file1.nca', 'file2.tik']);
        expect(reader.header.entries[0].size, file1Data.length);
        expect(reader.header.entries[1].size, file2Data.length);

        final read1 = await reader.readEntry(reader.header.entries[0]);
        final read2 = await reader.readEntry(reader.header.entries[1]);

        expect(read1, equals(file1Data));
        expect(read2, equals(file2Data));
      } finally {
        await readFile.close();
      }
    });

    test('supports resizing files dynamically during build', () async {
      final file = await File('${tempDir.path}/test_resize.hfs0').open(mode: FileMode.write);
      final builder = Hfs0Builder(file: file, startOffset: 0, headerReservedSize: 0x8000);
      await builder.begin();

      final initialData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final actualData = Uint8List.fromList([1, 2, 3]);

      await builder.addFile('resized.bin', initialData.length);
      await file.writeFrom(actualData);
      builder.resizeFile('resized.bin', actualData.length);
      await builder.finalizeFileWrite('resized.bin');

      await builder.end();
      await file.close();

      // Read back
      final readFile = await File('${tempDir.path}/test_resize.hfs0').open(mode: FileMode.read);
      final reader = Hfs0Reader(readFile, 0);
      try {
        await reader.initialize();
        expect(reader.header.entries.single.name, 'resized.bin');
        expect(reader.header.entries.single.size, actualData.length);

        final read = await reader.readEntry(reader.header.entries.single);
        expect(read, equals(actualData));
      } finally {
        await readFile.close();
      }
    });
  });
}
