import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/ppf_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('PPF patch reproduces the known patched ROM', () async {
    final inputs = requireInputs({
      'PPF_ROM': 'original ROM',
      'PPF_PATCH': '.ppf patch file',
      'PPF_EXPECTED': 'known patched ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('PPF_DST');
    if (destination == null) return;

    final original = File(inputs['PPF_ROM']!);
    final patch = File(inputs['PPF_PATCH']!);
    final expected = File(inputs['PPF_EXPECTED']!);
    final output = File('${destination.path}/out.bin');
    if (output.existsSync()) await output.delete();

    await PpfPatcher(
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
