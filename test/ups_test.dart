import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/ups_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('UPS patch reproduces the known patched GBA ROM', () async {
    final inputs = requireInputs({
      'UPS_ROM': 'original GBA ROM',
      'UPS_PATCH': '.ups patch file',
      'UPS_EXPECTED': 'known patched GBA ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('UPS_DST');
    if (destination == null) return;

    final original = File(inputs['UPS_ROM']!);
    final patch = File(inputs['UPS_PATCH']!);
    final expected = File(inputs['UPS_EXPECTED']!);
    final output = File('${destination.path}/out.gba');
    if (output.existsSync()) await output.delete();

    await UpsPatcher(
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
