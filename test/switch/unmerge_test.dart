// ignore_for_file: avoid_print
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/switch/merger.dart';
import 'package:final_rom/switch/unmerger.dart';
import 'package:final_rom/switch/keys.dart';
import 'package:final_rom/switch/pfs0.dart';

import '../support/test_env.dart';

// Merge two NSPs, unmerge the result, and check every split output reproduces
// its source members byte-for-byte. Set UNMERGE_NSP1, UNMERGE_NSP2, SWITCH_KEYS
// and UNMERGE_DST (in .env or the environment) to run; otherwise it skips.
//   flutter test test/unmerge_test.dart --timeout=none

Future<List<String>> _members(String path) async {
  final reader = await Pfs0Reader.open(path);
  try {
    return reader.entries.map((entry) => entry.name).toList();
  } finally {
    await reader.close();
  }
}

class _DigestSink implements Sink<Digest> {
  final void Function(Digest) onDigest;
  _DigestSink(this.onDigest);
  @override
  void add(Digest data) => onDigest(data);
  @override
  void close() {}
}

// Member name -> SHA-256 of that member's payload. Invariant to PFS0 padding
// and member order, so it captures content identity rather than file identity.
Future<Map<String, String>> _memberHashes(String path) async {
  final reader = await Pfs0Reader.open(path);
  try {
    final hashes = <String, String>{};
    for (final entry in reader.entries) {
      Digest? captured;
      final hasher =
          sha256.startChunkedConversion(_DigestSink((digest) => captured = digest));
      var position = 0;
      const chunkSize = 8 * 1024 * 1024;
      while (position < entry.dataSize) {
        final take = (entry.dataSize - position) < chunkSize
            ? (entry.dataSize - position)
            : chunkSize;
        hasher.add(
            await reader.readEntry(entry, offsetInEntry: position, length: take));
        position += take;
      }
      hasher.close();
      hashes[entry.name] = captured.toString();
    }
    return hashes;
  } finally {
    await reader.close();
  }
}

void main() {
  final nsp1 = envPath('UNMERGE_NSP1');
  final nsp2 = envPath('UNMERGE_NSP2');
  final keysPath = envPath('SWITCH_KEYS');
  final destPath = envPath('UNMERGE_DST');

  final missing = {
    'UNMERGE_NSP1': nsp1,
    'UNMERGE_NSP2': nsp2,
    'SWITCH_KEYS': keysPath,
    'UNMERGE_DST': destPath,
  }.entries.where((entry) => entry.value == null).map((entry) => entry.key);
  final skip = missing.isEmpty
      ? null
      : 'set ${missing.join(', ')} (in .env or the environment)';

  group('NSP unmerge round-trip', () {
    late String mergedPath;
    late String splitDir;
    late SwitchKeys keys;

    setUpAll(() async {
      final dest = Directory(destPath!)..createSync(recursive: true);
      keys = SwitchKeys.parse(await File(keysPath!).readAsString());
      mergedPath = '${dest.path}/merged.nsp';
      splitDir = '${dest.path}/split';
      await NspMerger.merge([nsp1!, nsp2!], mergedPath);
    });

    test('merge produces a valid merged NSP', () async {
      final members = await _members(mergedPath);
      expect(members, isNotEmpty);
      print('[OK] merged.nsp has ${members.length} members');
    });

    test('unmerge splits the merged NSP back into per-title NSPs', () async {
      await Directory(splitDir).create(recursive: true);

      final result = await NspUnmerger.unmerge(
        mergedPath,
        splitDir,
        keys: keys,
        onProgress: (message, fraction) => stdout.write('\r$message          '),
      );
      print('');

      expect(result.outputs, isNotEmpty);
      for (final output in result.outputs) {
        print('[OK] ${output.outputPath} '
            'titleId=0x${output.titleId.toRadixString(16)} '
            'type=${output.metaType} missing=${output.missingNcaIds.length}');
        expect(output.missingNcaIds, isEmpty,
            reason: 'Unexpected missing NCAs for ${output.outputPath}');
      }

      final mergedMembers = (await _members(mergedPath)).toSet();
      final splitMembersUnion = <String>{};
      for (final output in result.outputs) {
        splitMembersUnion.addAll(await _members(output.outputPath));
      }
      expect(splitMembersUnion, equals(mergedMembers),
          reason: 'split members must reproduce the merged NSP exactly');

      final nsp1Members = (await _members(nsp1!)).toSet();
      final nsp2Members = (await _members(nsp2!)).toSet();
      for (final output in result.outputs) {
        final outMembers = (await _members(output.outputPath)).toSet();
        final fromInput1 = outMembers.difference(nsp1Members).isEmpty;
        final fromInput2 = outMembers.difference(nsp2Members).isEmpty;
        expect(fromInput1 || fromInput2, isTrue,
            reason:
                '${output.outputPath} members are not a subset of either input');
      }
    });

    test('split outputs carry byte-identical content to the original inputs',
        () async {
      final outputs = Directory(splitDir)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.nsp'))
          .map((file) => file.path)
          .toList();
      expect(outputs, isNotEmpty, reason: 'split step must run before this test');

      final originalHashes = <String, String>{};
      originalHashes.addAll(await _memberHashes(nsp1!));
      originalHashes.addAll(await _memberHashes(nsp2!));

      for (final output in outputs) {
        final outHashes = await _memberHashes(output);
        for (final entry in outHashes.entries) {
          final expected = originalHashes[entry.key];
          expect(expected, isNotNull,
              reason: '${entry.key} in $output has no original counterpart');
          expect(entry.value, equals(expected),
              reason: '${entry.key} payload differs from the original input');
        }
        print('[OK] $output: ${outHashes.length} members content-identical');
      }
    });
  }, skip: skip);
}
