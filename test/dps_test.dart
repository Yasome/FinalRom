import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/dps_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('DPS patch reproduces the known patched ROM', () async {
    final inputs = requireInputs({
      'DPS_ROM': 'original ROM',
      'DPS_PATCH': '.dps patch file',
      'DPS_EXPECTED': 'known patched ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('DPS_DST');
    if (destination == null) return;

    final original = File(inputs['DPS_ROM']!);
    final patch = File(inputs['DPS_PATCH']!);
    final expected = File(inputs['DPS_EXPECTED']!);
    final output = File('${destination.path}/out.bin');
    if (output.existsSync()) await output.delete();

    await DpsPatcher(
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
  });
}
