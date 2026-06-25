import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_rom/final_rom.dart';

import 'support/test_env.dart';

// Set THREEDS_KEYS, THREEDS_SRC and THREEDS_DST (in .env or the environment) to
// run. The test encrypts the base ROM, decrypts the result, and checks the NCSD
// header survives the round-trip. Without the vars it skips.

bool _isNcsd(Uint8List bytes) =>
    bytes[0x100] == 0x4E && // N
    bytes[0x101] == 0x43 && // C
    bytes[0x102] == 0x53 && // S
    bytes[0x103] == 0x44; // D

void main() {
  test('3DS encrypt then decrypt preserves the NCSD header', () async {
    final inputs = requireInputs({
      'THREEDS_KEYS': '3DS keys file',
      'THREEDS_SRC': 'base .3ds ROM',
    });
    if (inputs == null) return;
    final destination = requireDest('THREEDS_DST');
    if (destination == null) return;

    final keys =
        ThreeDsKeys.parse(await File(inputs['THREEDS_KEYS']!).readAsString());

    final encrypted = File('${destination.path}/out-encrypted.3ds');
    final decrypted = File('${destination.path}/out-decrypted.3ds');
    for (final stale in [encrypted, decrypted]) {
      if (stale.existsSync()) await stale.delete();
    }

    final encryptedPath = await encrypt3ds(
      inputs['THREEDS_SRC']!,
      keys: keys,
      outputPath: encrypted.path,
      inPlace: false,
    );
    expect(encryptedPath, encrypted.path);
    expect(_isNcsd(await encrypted.readAsBytes()), isTrue,
        reason: 'encrypted output is not a valid NCSD');

    final decryptedPath = await decrypt3ds(
      encrypted.path,
      keys: keys,
      outputPath: decrypted.path,
      inPlace: false,
      trim: true,
    );
    expect(decryptedPath, decrypted.path);
    expect(_isNcsd(await decrypted.readAsBytes()), isTrue,
        reason: 'decrypted output is not a valid NCSD');
  });
}
