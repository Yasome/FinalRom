import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:final_rom/patcher/ips_patcher.dart';

import 'support/test_env.dart';

void main() {
  test('IPS patch reproduces the known patched NES ROM', () async {
    final inputs = requireInputs({
      'IPS_ROM': 'original NES ROM',
      'IPS_PATCH': '.ips patch file',
      'IPS_EXPECTED': 'known patched NES ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('IPS_DST');
    if (destination == null) return;

    final original = File(inputs['IPS_ROM']!);
    final patch = File(inputs['IPS_PATCH']!);
    final expected = File(inputs['IPS_EXPECTED']!);
    final output = File('${destination.path}/out.nes');
    if (output.existsSync()) await output.delete();

    await IpsPatcher(
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
