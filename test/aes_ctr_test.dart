import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbedtls_ffi/mbedtls_ffi.dart';
import 'package:pointycastle/export.dart';

import 'package:final_rom/src/aes_ctr.dart';
import 'package:final_rom/src/big_int_ops.dart';

Uint8List _hex(String s) {
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(s.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

/// Reference AES-128-CTR using pointycastle directly, over the whole buffer in
/// one shot — the ground truth the native cipher must match.
Uint8List _pointyCastle(Uint8List key, Uint8List counter, Uint8List data) {
  final cipher = CTRStreamCipher(AESEngine())
    ..init(true,
        ParametersWithIV<KeyParameter>(KeyParameter(key), counter));
  return cipher.process(data);
}

void main() {
  // NIST SP800-38A F.5.1 CTR-AES128.Encrypt, all four blocks.
  final nistKey = _hex('2b7e151628aed2a6abf7158809cf4f3c');
  final nistCtr = _hex('f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff');
  final nistPlain = _hex('6bc1bee22e409f96e93d7e117393172a'
      'ae2d8a571e03ac9c9eb76fac45af8e51'
      '30c81c46a35ce411e5fbc1191a0a52ef'
      'f69f2445df4f9b17ad2b417be66c3710');
  final nistCipher = _hex('874d6191b620e3261bef6864990db6ce'
      '9806f66b7970fdff8617187bb9fffdff'
      '5ae4df3edbd5d35e5b4f09020db03eab'
      '1e031dda2fbe03d1792170a0f3009cee');

  test('AesCtr matches the NIST SP800-38A CTR-AES128 vector', () {
    final cipher = AesCtr.fromBigInts(
        bigIntFromBytesBE(nistKey), bigIntFromBytesBE(nistCtr));
    expect(cipher.process(nistPlain), equals(nistCipher));
    cipher.dispose();
  });

  test('feeding odd chunk sizes yields the same stream (counter carry)', () {
    // Works on either backend: the keystream is position-based, so splitting
    // the input at sub-block boundaries must not change the output.
    final rnd = Random(1234);
    final data = Uint8List.fromList(
        List<int>.generate(4096 + 37, (_) => rnd.nextInt(256)));

    final oneShot = AesCtr.fromBigInts(
        bigIntFromBytesBE(nistKey), bigIntFromBytesBE(nistCtr));
    final whole = oneShot.process(data);
    oneShot.dispose();

    final chunked = AesCtr.fromBigInts(
        bigIntFromBytesBE(nistKey), bigIntFromBytesBE(nistCtr));
    final out = BytesBuilder();
    var offset = 0;
    for (final size in [1, 15, 16, 17, 31, 33, 1000, 2048]) {
      if (offset >= data.length) break;
      final end = (offset + size).clamp(0, data.length);
      out.add(chunked.process(Uint8List.sublistView(data, offset, end)));
      offset = end;
    }
    if (offset < data.length) {
      out.add(chunked.process(Uint8List.sublistView(data, offset)));
    }
    chunked.dispose();

    expect(out.toBytes(), equals(whole));
  });

  group('native vs pointycastle equivalence', () {
    // Meaningful only when the native library is loadable; the bare `flutter
    // test` VM can't load the plugin dylib, so this verifies on desktop builds.
    test('random keys/counters/lengths and odd chunkings agree', () {
      if (!mbedtlsFfiAvailable) {
        markTestSkipped('mbedtls_ffi native library unavailable');
        return;
      }
      final rnd = Random(0xC0FFEE);
      for (var trial = 0; trial < 50; trial++) {
        final key = Uint8List.fromList(
            List<int>.generate(16, (_) => rnd.nextInt(256)));
        final counter = Uint8List.fromList(
            List<int>.generate(16, (_) => rnd.nextInt(256)));
        final len = rnd.nextInt(9000);
        final data = Uint8List.fromList(
            List<int>.generate(len, (_) => rnd.nextInt(256)));

        final reference = _pointyCastle(key, counter, data);

        final native = AesCtr.fromBigInts(
            bigIntFromBytesBE(key), bigIntFromBytesBE(counter));
        final out = BytesBuilder();
        var offset = 0;
        while (offset < data.length) {
          final size = 1 + rnd.nextInt(300); // random sub-block-ish chunks
          final end = (offset + size).clamp(0, data.length);
          out.add(native.process(Uint8List.sublistView(data, offset, end)));
          offset = end;
        }
        native.dispose();

        expect(out.toBytes(), equals(reference),
            reason: 'trial $trial (len=$len) native output diverged');
      }
    });
  });
}
