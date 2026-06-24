import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/bps_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('BPS patch reproduces the known patched SNES ROM', () async {
    final inputs = requireInputs({
      'BPS_ROM': 'original SNES ROM',
      'BPS_PATCH': '.bps patch file',
      'BPS_EXPECTED': 'known patched SNES ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('BPS_DST');
    if (destination == null) return;

    final original = File(inputs['BPS_ROM']!);
    final patch = File(inputs['BPS_PATCH']!);
    final expected = File(inputs['BPS_EXPECTED']!);
    final output = File('${destination.path}/out.sfc');
    if (output.existsSync()) await output.delete();

    await BpsPatcher(
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
  }, timeout: const Timeout(Duration(minutes: 3)));
}
