import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/switch/xci_reader.dart';

const _hfs0Magic = 0x30534648; // 'HFS0'
const _headMagic = 0x44414548; // 'HEAD'
const _hfs0HeaderSize = 16;
const _hfs0EntrySize = 64;

int _stringTableSize(Iterable<String> names) {
  final raw = names.fold<int>(0, (sum, name) => sum + name.length + 1);
  return (raw + 3) & ~3; // HFS0 string tables are 4-byte aligned
}

// Builds one HFS0 partition: header, a 64-byte entry per file, the name string
// table, then the file contents laid out contiguously.
Uint8List _buildHfs0(List<({String name, Uint8List data})> files) {
  final nameOffsets = <int>[];
  final names = BytesBuilder();
  for (final file in files) {
    nameOffsets.add(names.length);
    names.add(file.name.codeUnits);
    names.addByte(0);
  }
  final stringTable = Uint8List(_stringTableSize(files.map((f) => f.name)))
    ..setRange(0, names.length, names.toBytes());

  final out = BytesBuilder();
  final header = ByteData(_hfs0HeaderSize)
    ..setUint32(0, _hfs0Magic, Endian.little)
    ..setUint32(4, files.length, Endian.little)
    ..setUint32(8, stringTable.length, Endian.little);
  out.add(header.buffer.asUint8List());

  var dataOffset = 0;
  for (var i = 0; i < files.length; i++) {
    final entry = ByteData(_hfs0EntrySize)
      ..setUint64(0, dataOffset, Endian.little)
      ..setUint64(8, files[i].data.length, Endian.little)
      ..setUint32(16, nameOffsets[i], Endian.little);
    out.add(entry.buffer.asUint8List());
    dataOffset += files[i].data.length;
  }

  out.add(stringTable);
  for (final file in files) {
    out.add(file.data);
  }
  return out.toBytes();
}

int _dataRegion(int partitionOffset, int entryCount, Iterable<String> names) =>
    partitionOffset +
    _hfs0HeaderSize +
    entryCount * _hfs0EntrySize +
    _stringTableSize(names);

void main() {
  group('XciReader', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('xci_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('resolves member offsets through the nested secure HFS0', () async {
      final file1 = Uint8List.fromList(List.filled(10, 0x01));
      final file2 = Uint8List.fromList(List.filled(20, 0x02));

      // A secure partition holding two NCAs, wrapped in a root partition whose
      // single "secure" entry points at it.
      final secure = _buildHfs0([
        (name: 'file1.nca', data: file1),
        (name: 'file2.nca', data: file2),
      ]);
      final root = _buildHfs0([(name: 'secure', data: secure)]);

      // XCI layout: 0x100 of padding, then a 512-byte card header whose
      // hfs0_offset (at 0x30) points past it to the root partition.
      const rootOffset = 0x300;
      final cardHeader = ByteData(512)
        ..setUint32(0, _headMagic, Endian.little)
        ..setUint64(0x30, rootOffset, Endian.little);

      final image = BytesBuilder()
        ..add(Uint8List(0x100))
        ..add(cardHeader.buffer.asUint8List())
        ..add(root);

      final outPath = '${tempDir.path}/test.xci';
      await File(outPath).writeAsBytes(image.toBytes());

      final secureOffset = _dataRegion(rootOffset, 1, ['secure']);
      final secureData =
          _dataRegion(secureOffset, 2, ['file1.nca', 'file2.nca']);

      final reader = await XciReader.open(outPath);
      try {
        expect(reader.entries.map((entry) => entry.name),
            ['file1.nca', 'file2.nca']);
        expect(reader.entries[0].size, file1.length);
        expect(reader.entries[1].size, file2.length);
        expect(reader.entries[0].offset, secureData);
        expect(reader.entries[1].offset, secureData + file1.length);
      } finally {
        await reader.close();
      }
    });
  });
}
