// ignore_for_file: avoid_print
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'support/test_env.dart';

// Benchmarks the old per-member merge against the current reused-handle merge
// and checks both produce byte-identical, valid PFS0 containers. Set MERGE_NSP1
// and MERGE_NSP2 (in .env or the environment) to run; otherwise it skips.
//   flutter test test/merge_benchmark.dart --timeout=none

const _magic = [0x50, 0x46, 0x53, 0x30]; // 'PFS0'
const _headerBase = 0x10;
const _entrySize = 0x18;

void main() {
  final nsp1 = envPath('MERGE_NSP1');
  final nsp2 = envPath('MERGE_NSP2');
  final missing = {
    'MERGE_NSP1': nsp1,
    'MERGE_NSP2': nsp2,
  }.entries.where((entry) => entry.value == null).map((entry) => entry.key);
  final skip = missing.isEmpty
      ? null
      : 'set ${missing.join(', ')} (in .env or the environment)';

  group('NSP merge benchmark', () {
    final outputOld = '${Directory.systemTemp.path}/bench_merge_old.nsp';
    final outputNew = '${Directory.systemTemp.path}/bench_merge_new.nsp';

    test('inputs exist and are valid PFS0', () async {
      for (final path in [nsp1!, nsp2!]) {
        final file = await File(path).open();
        final header = await _readAt(file, 0, 4);
        await file.close();
        expect(header, equals(Uint8List.fromList(_magic)),
            reason: '$path is not PFS0');
        print('[OK]  $path  (${_formatBytes(File(path).lengthSync())})');
      }
    });

    test('OLD approach: re-open per member, 8 MB chunks, RandomAccessFile write',
        () async {
      final stopwatch = Stopwatch()..start();
      final total = await _mergeOld([nsp1!, nsp2!], outputOld,
          onProgress: (message, _) => stdout.write('\r[OLD] $message          '));
      stopwatch.stop();
      print('');
      _printThroughput('OLD', total, stopwatch);
    });

    test('NEW approach: reused handles, 32 MB chunks, IOSink write', () async {
      final stopwatch = Stopwatch()..start();
      final total = await _mergeNew([nsp1!, nsp2!], outputNew,
          onProgress: (message, _) => stdout.write('\r[NEW] $message          '));
      stopwatch.stop();
      print('');
      _printThroughput('NEW', total, stopwatch);
    });

    test('OLD and NEW outputs are byte-identical', () async {
      final oldFile = await File(outputOld).open();
      final newFile = await File(outputNew).open();
      try {
        final oldLength = await oldFile.length();
        final newLength = await newFile.length();
        expect(oldLength, equals(newLength), reason: 'File sizes differ');

        // 64 MB blocks keep peak memory bounded on multi-GB files.
        const blockSize = 64 * 1024 * 1024;
        var offset = 0;
        while (offset < oldLength) {
          final take =
              (offset + blockSize) < oldLength ? blockSize : (oldLength - offset);
          expect(await _readAt(oldFile, offset, take),
              equals(await _readAt(newFile, offset, take)),
              reason: 'Mismatch at byte offset $offset–${offset + take}');
          offset += take;
        }
        print('[OK]  Both outputs are byte-identical (${_formatBytes(newLength)})');
      } finally {
        await oldFile.close();
        await newFile.close();
      }
    });

    test('output PFS0 structure is valid', () {
      _validatePfs0(outputNew);
    });

    test('output members are the union of both inputs (no dupes, none missing)',
        () async {
      final outMembers = _readPfs0Members(outputNew);
      final seen = <String>{};
      final expected = <String>[];
      for (final path in [nsp1!, nsp2!]) {
        for (final name in _readPfs0Members(path)) {
          if (seen.add(name)) expected.add(name);
        }
      }
      expect(outMembers, equals(expected));
      print('[OK]  Members (${outMembers.length}): ${outMembers.join(', ')}');
    });

    tearDownAll(() async {
      for (final path in [outputOld, outputNew]) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    });
  }, skip: skip);
}

void _printThroughput(String label, int totalBytes, Stopwatch stopwatch) {
  final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
  final megabytesPerSecond = (totalBytes / 1024 / 1024) / elapsedSeconds;
  print('[$label] ${_formatBytes(totalBytes)} in '
      '${elapsedSeconds.toStringAsFixed(1)}s  '
      '→  ${megabytesPerSecond.toStringAsFixed(1)} MB/s');
}

// Mirrors the merge code before the optimisation: reopen each member, read in
// 8 MB chunks, and write with blocking RandomAccessFile.writeFrom.
Future<int> _mergeOld(
  List<String> inputs,
  String output, {
  void Function(String, double)? onProgress,
}) async {
  final members = await _collectMembers(inputs);
  final header = _buildHeader(members);
  final totalBytes = members.fold<int>(0, (sum, member) => sum + member.size);
  var written = 0;

  final sink = await File(output).open(mode: FileMode.write);
  try {
    await sink.writeFrom(header);
    for (final member in members) {
      final source = await File(member.path).open(mode: FileMode.read);
      try {
        await source.setPosition(member.offset);
        var remaining = member.size;
        const chunkSize = 8 * 1024 * 1024;
        while (remaining > 0) {
          final take = remaining < chunkSize ? remaining : chunkSize;
          final bytes = await source.read(take);
          await sink.writeFrom(bytes);
          remaining -= bytes.length;
          written += bytes.length;
          onProgress?.call(
              '${_formatBytes(written)} / ${_formatBytes(totalBytes)}',
              written / totalBytes);
        }
      } finally {
        await source.close();
      }
    }
  } finally {
    await sink.close();
  }
  return totalBytes;
}

// Matches the current Pfs0Builder.writeTo: reuse one handle per source file,
// read in 32 MB chunks, and write through a buffered IOSink.
Future<int> _mergeNew(
  List<String> inputs,
  String output, {
  void Function(String, double)? onProgress,
}) async {
  final members = await _collectMembers(inputs);
  final header = _buildHeader(members);
  final totalBytes = members.fold<int>(0, (sum, member) => sum + member.size);
  var written = 0;

  final sink = File(output).openWrite();
  try {
    sink.add(header);
    final handles = <String, RandomAccessFile>{};
    try {
      for (final member in members) {
        final handle =
            handles[member.path] ??= await File(member.path).open(mode: FileMode.read);
        await handle.setPosition(member.offset);
        var remaining = member.size;
        const chunkSize = 32 * 1024 * 1024;
        while (remaining > 0) {
          final take = remaining < chunkSize ? remaining : chunkSize;
          final bytes = await handle.read(take);
          sink.add(bytes);
          remaining -= bytes.length;
          written += bytes.length;
          onProgress?.call(
              '${_formatBytes(written)} / ${_formatBytes(totalBytes)}',
              written / totalBytes);
          // Yield periodically so the buffered sink can drain to disk.
          if (written % (256 * 1024 * 1024) < chunkSize) {
            await Future.delayed(Duration.zero);
          }
        }
      }
    } finally {
      for (final handle in handles.values) {
        await handle.close();
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
  return totalBytes;
}

class _Member {
  final String name, path;
  final int offset, size;
  _Member(this.name, this.path, this.offset, this.size);
}

Future<List<_Member>> _collectMembers(List<String> paths) async {
  final seen = <String>{};
  final members = <_Member>[];
  for (final path in paths) {
    final file = await File(path).open();
    try {
      final header = ByteData.sublistView(await _readAt(file, 0, _headerBase));
      final count = header.getUint32(4, Endian.little);
      final nameTableSize = header.getUint32(8, Endian.little);
      final entryBytes = await _readAt(file, _headerBase, count * _entrySize);
      final nameBytes =
          await _readAt(file, _headerBase + count * _entrySize, nameTableSize);
      final dataRegion = _headerBase + count * _entrySize + nameTableSize;
      final entries = ByteData.sublistView(entryBytes);
      for (var i = 0; i < count; i++) {
        final base = i * _entrySize;
        final relativeOffset = entries.getUint64(base, Endian.little);
        final size = entries.getUint64(base + 8, Endian.little);
        final nameOffset = entries.getUint32(base + 16, Endian.little);
        final name = _cstring(nameBytes, nameOffset);
        if (seen.add(name)) {
          members.add(_Member(name, path, dataRegion + relativeOffset, size));
        }
      }
    } finally {
      await file.close();
    }
  }
  return members;
}

Uint8List _buildHeader(List<_Member> members) {
  final nameTable = BytesBuilder();
  final nameOffsets = <int>[];
  for (final member in members) {
    nameOffsets.add(nameTable.length);
    nameTable.add(member.name.codeUnits);
    nameTable.addByte(0);
  }
  final unpaddedSize = _headerBase + members.length * _entrySize + nameTable.length;
  final padding = 0x20 - (unpaddedSize % 0x20);
  final nameTableSize = nameTable.length + padding;

  final output = BytesBuilder();
  final fields = ByteData(_headerBase);
  for (var i = 0; i < _magic.length; i++) {
    fields.setUint8(i, _magic[i]);
  }
  fields.setUint32(4, members.length, Endian.little);
  fields.setUint32(8, nameTableSize, Endian.little);
  output.add(fields.buffer.asUint8List());

  var runningOffset = 0;
  for (var i = 0; i < members.length; i++) {
    final entry = ByteData(_entrySize);
    entry.setUint64(0, runningOffset, Endian.little);
    entry.setUint64(8, members[i].size, Endian.little);
    entry.setUint32(16, nameOffsets[i], Endian.little);
    output.add(entry.buffer.asUint8List());
    runningOffset += members[i].size;
  }
  output.add(nameTable.toBytes());
  output.add(Uint8List(padding));
  return output.toBytes();
}

List<String> _readPfs0Members(String path) {
  final file = File(path).openSync();
  try {
    final header = ByteData.sublistView(_readSyncAt(file, 0, _headerBase));
    final count = header.getUint32(4, Endian.little);
    final nameTableSize = header.getUint32(8, Endian.little);
    final nameBytes =
        _readSyncAt(file, _headerBase + count * _entrySize, nameTableSize);
    final entries = ByteData.sublistView(_readSyncAt(file, _headerBase, count * _entrySize));
    return [
      for (var i = 0; i < count; i++)
        _cstring(nameBytes, entries.getUint32(i * _entrySize + 16, Endian.little)),
    ];
  } finally {
    file.closeSync();
  }
}

void _validatePfs0(String path) {
  final file = File(path).openSync();
  try {
    final header = ByteData.sublistView(_readSyncAt(file, 0, _headerBase));
    expect(header.buffer.asUint8List(0, 4), equals(Uint8List.fromList(_magic)));
    final count = header.getUint32(4, Endian.little);
    expect(count, greaterThan(0));
    final nameTableSize = header.getUint32(8, Endian.little);
    final dataRegion = _headerBase + count * _entrySize + nameTableSize;
    final fileLength = file.lengthSync();
    final entries = ByteData.sublistView(_readSyncAt(file, _headerBase, count * _entrySize));
    for (var i = 0; i < count; i++) {
      final relativeOffset = entries.getUint64(i * _entrySize, Endian.little);
      final size = entries.getUint64(i * _entrySize + 8, Endian.little);
      expect(dataRegion + relativeOffset + size, lessThanOrEqualTo(fileLength),
          reason: 'Entry $i overflows file');
    }
    print('[OK]  $path  valid PFS0 ($count members, ${_formatBytes(fileLength)})');
  } finally {
    file.closeSync();
  }
}

Future<Uint8List> _readAt(RandomAccessFile file, int offset, int length) async {
  if (length == 0) return Uint8List(0);
  await file.setPosition(offset);
  final out = Uint8List(length);
  var read = 0;
  while (read < length) {
    final chunk = await file.read(length - read);
    if (chunk.isEmpty) throw Exception('Unexpected EOF at offset $offset');
    out.setRange(read, read + chunk.length, chunk);
    read += chunk.length;
  }
  return out;
}

Uint8List _readSyncAt(RandomAccessFile file, int offset, int length) {
  file.setPositionSync(offset);
  return file.readSync(length);
}

String _cstring(Uint8List bytes, int offset) {
  var end = offset;
  while (end < bytes.length && bytes[end] != 0) {
    end++;
  }
  return String.fromCharCodes(bytes.sublist(offset, end));
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
