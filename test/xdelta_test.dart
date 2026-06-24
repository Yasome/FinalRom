import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/xdelta_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('xdelta patch reproduces the known patched ROM', () async {
    final inputs = requireInputs({
      'XDELTA_ROM': 'original ROM',
      'XDELTA_PATCH': '.xdelta/.vcdiff patch file',
      'XDELTA_EXPECTED': 'known patched ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('XDELTA_DST');
    if (destination == null) return;

    final original = File(inputs['XDELTA_ROM']!);
    final patch = File(inputs['XDELTA_PATCH']!);
    final expected = File(inputs['XDELTA_EXPECTED']!);
    final output = File('${destination.path}/out.bin');
    if (output.existsSync()) await output.delete();

    await XdeltaPatcher(
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
