import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/aps_patcher.dart';

import 'support/test_env.dart';

Future<void> _runApsPatch(Map<String, String> inputs, Directory destination,
    {required String romVar,
    required String patchVar,
    required String expectedVar}) async {
  final original = File(inputs[romVar]!);
  final patch = File(inputs[patchVar]!);
  final expected = File(inputs[expectedVar]!);
  final output = File('${destination.path}/out.bin');
  if (output.existsSync()) await output.delete();

  await ApsPatcher(
    patchFile: patch,
    romFile: original,
    outputFile: output,
  ).apply();

  final expectedBytes = await expected.readAsBytes();
  final actualBytes = await output.readAsBytes();

  expect(actualBytes.length, expectedBytes.length,
      reason: 'patched ROM size differs');
  expect(sha256.convert(actualBytes).toString(),
      sha256.convert(expectedBytes).toString(),
      reason: 'patched ROM content differs');
}

void main() {
  test('APS (GBA) patch reproduces the known patched ROM', () async {
    final inputs = requireInputs({
      'APS_GBA_ROM': 'original GBA ROM',
      'APS_GBA_PATCH': '.aps (GBA) patch file',
      'APS_GBA_EXPECTED': 'known patched GBA ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('APS_GBA_DST');
    if (destination == null) return;

    await _runApsPatch(inputs, destination,
        romVar: 'APS_GBA_ROM',
        patchVar: 'APS_GBA_PATCH',
        expectedVar: 'APS_GBA_EXPECTED');
  });

  test('APS (N64) patch reproduces the known patched ROM', () async {
    final inputs = requireInputs({
      'APS_N64_ROM': 'original N64 ROM',
      'APS_N64_PATCH': '.aps (N64) patch file',
      'APS_N64_EXPECTED': 'known patched N64 ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('APS_N64_DST');
    if (destination == null) return;

    await _runApsPatch(inputs, destination,
        romVar: 'APS_N64_ROM',
        patchVar: 'APS_N64_PATCH',
        expectedVar: 'APS_N64_EXPECTED');
  });
}
