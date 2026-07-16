import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/ebp_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('EBP patch reproduces the known patched ROM', () async {
    final inputs = requireInputs({
      'EBP_ROM': 'original SNES ROM',
      'EBP_PATCH': '.ebp patch file',
      'EBP_EXPECTED': 'known patched ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('EBP_DST');
    if (destination == null) return;

    final original = File(inputs['EBP_ROM']!);
    final patch = File(inputs['EBP_PATCH']!);
    final expected = File(inputs['EBP_EXPECTED']!);
    final output = File('${destination.path}/out.bin');
    if (output.existsSync()) await output.delete();

    await EbpPatcher(
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
