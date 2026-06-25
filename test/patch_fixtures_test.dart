import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/patcher.dart';
import 'package:final_rom/patcher/patcher_factory.dart';

const _fixtures = 'test/fixtures/patches';

typedef _Triple = ({String name, String rom, String patch, String expected});

typedef _HashTriple = ({
  String name,
  String dir,
  String patch,
  String sourceHash,
  String patchHash,
  String modifiedHash,
});

final _hashTriples = <_HashTriple>[
  (
    name: 'EBP',
    dir: 'ebp',
    patch: 'patch.ebp',
    sourceHash: '229001832f19165ae3a2ecb80fe8034a7d96e6b13ff5aab33f81d8be437d4a51',
    patchHash: 'de8ef00b92d0ee6b94e0e069129b315181336460260e3c0d99cee68964b8a3df',
    modifiedHash: '43b5eaf970d3a4ce3d0ed56ea89221984f366e7578cf5da2a6b8fa03d7cc81b2',
  ),
  (
    name: 'PPF',
    dir: 'ppf',
    patch: 'patch.ppf',
    sourceHash: '94123bb22d3fa8515cd2071bf016308816556dd4508f01bf18b5cc65b3c5e78a',
    patchHash: '99a3420c40765c3a5c7560220cbd8b53fd3e1bea030b03830a1c90da29e578e3',
    modifiedHash: 'edace804fb27a9e144a906f9b0417a80629d6e57d0fa11336d4b2716af0f6078',
  ),
  (
    name: 'DPS',
    dir: 'dps',
    patch: 'patch.dps',
    sourceHash: '94123bb22d3fa8515cd2071bf016308816556dd4508f01bf18b5cc65b3c5e78a',
    patchHash: 'f0aebfc7d586fd4bb724d5ecccfec2a458174ccd5bda795843252a0d3bbca85c',
    modifiedHash: 'ac412e48ac1ee409e1756f6bf6021d5c3ad399159ea10b516ffc804d13186484',
  ),
  (
    name: 'APS (N64)',
    dir: 'aps',
    patch: 'patch.aps',
    sourceHash: '94123bb22d3fa8515cd2071bf016308816556dd4508f01bf18b5cc65b3c5e78a',
    patchHash: 'd5bca60f762974b7bb08ea19596e30b842acd5db2ad1b70c7d47b4596bda6e6d',
    modifiedHash: '1f792c5d5426cd8d4e453b9fae41593590e126bba19015f80d843ac014792bb5',
  ),
];

final _triples = <_Triple>[
  (name: 'IPS min', rom: 'ips/min_ips.bin', patch: 'ips/min_ips.ips', expected: 'ips/min_ips_modified.bin'),
  (name: 'IPS rle', rom: 'ips/rle_ips.bin', patch: 'ips/rle_ips.ips', expected: 'ips/rle_ips_modified.bin'),
  (name: 'IPS extend', rom: 'ips/extend_ips.bin', patch: 'ips/extend_ips.ips', expected: 'ips/extend_ips_modified.bin'),
  (name: 'IPS truncate', rom: 'ips/truncate.bin', patch: 'ips/truncate.ips', expected: 'ips/truncate_modified.bin'),
  (name: 'IPS32 min', rom: 'ips/min_ips32.bin', patch: 'ips/min_ips32.ips', expected: 'ips/min_ips32_mod.bin'),
  (name: 'IPS32 rle', rom: 'ips/rle_ips32.bin', patch: 'ips/rle_ips32.ips', expected: 'ips/rle_ips32_mod.bin'),
  (name: 'IPS32 extend', rom: 'ips/extend_ips32.bin', patch: 'ips/extend_ips32.ips', expected: 'ips/extend_ips32_mod.bin'),
  (name: 'UPS', rom: 'ups/readUpsCrc.bin', patch: 'ups/readUpsCrc.ups', expected: 'ups/readUpsCrc_m.bin'),
  (name: 'BPS', rom: 'bps/1.bin', patch: 'bps/1.bps', expected: 'bps/1m.bin'),
];

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('patch_fixtures');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  for (final triple in _triples) {
    test('${triple.name} fixture round-trip', () async {
      final output = File('${tempDir.path}/out.bin');
      await PatcherFactory.create(
        patchFile: File('$_fixtures/${triple.patch}'),
        romFile: File('$_fixtures/${triple.rom}'),
        outputFile: output,
      ).apply();

      final actual = await output.readAsBytes();
      final expected = await File('$_fixtures/${triple.expected}').readAsBytes();
      expect(actual, equals(expected),
          reason: '${triple.name}: patched output differs from expected');
    });
  }

  test('rejects a non-IPS patch', () {
    expect(
      PatcherFactory.create(
        patchFile: File('$_fixtures/ips/not_ips.ips'),
        romFile: File('$_fixtures/ips/min_ips.bin'),
        outputFile: File('${tempDir.path}/out.bin'),
      ).apply(),
      throwsA(isA<PatchException>()),
    );
  });

  // Generated fixtures (see tool/gen_patch_fixtures.dart) verified by the
  // original-ROM, patch, and modified-ROM SHA-256 hashes.
  for (final triple in _hashTriples) {
    test('${triple.name} fixture verifies all three hashes', () async {
      final source = File('$_fixtures/${triple.dir}/source.bin');
      final patch = File('$_fixtures/${triple.dir}/${triple.patch}');
      final output = File('${tempDir.path}/out.bin');

      expect(sha256.convert(await source.readAsBytes()).toString(),
          triple.sourceHash,
          reason: '${triple.name}: source ROM hash');
      expect(sha256.convert(await patch.readAsBytes()).toString(),
          triple.patchHash,
          reason: '${triple.name}: patch hash');

      await PatcherFactory.create(
        patchFile: patch,
        romFile: source,
        outputFile: output,
      ).apply();

      expect(sha256.convert(await output.readAsBytes()).toString(),
          triple.modifiedHash,
          reason: '${triple.name}: patched output hash');
    });
  }
}
