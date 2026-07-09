import 'dart:typed_data';

import 'package:mbedtls_ffi/mbedtls_ffi.dart';
import 'package:pointycastle/export.dart';

import 'big_int_ops.dart';

/// AES-128 in CTR mode, the equivalent of pycryptodome's
/// `AES.new(key, AES.MODE_CTR, counter=Counter.new(128, initial_value=iv))`.
///
/// The whole 16-byte IV is treated as a big-endian 128-bit counter that
/// increments by one per block, matching `Counter.new(128, ...)`. Because CTR
/// is a stream cipher, encryption and decryption are the identical XOR
/// operation, and the cipher keeps its counter state across [process] calls —
/// so callers can feed the data in chunks (the 1 MB / 16 MB loops in the
/// original scripts) and the keystream stays continuous.
///
/// The hot path is backed by the native Mbed TLS (PSA) AES-CTR
/// implementation via [NativeAesCtr]. When the native library is unavailable
/// (e.g. the bare Dart VM in unit tests), it transparently falls back to the
/// pure-Dart pointycastle cipher, which is byte-for-byte equivalent.
class AesCtr {
  final NativeAesCtr? _native;
  final CTRStreamCipher? _fallback;

  AesCtr._(this._native, this._fallback);

  /// Build a cipher from a 128-bit key value and a 128-bit initial counter
  /// value (both [BigInt]).
  factory AesCtr.fromBigInts(BigInt key, BigInt counter) {
    final keyBytes = bigIntTo16Bytes(key);
    final counterBytes = bigIntTo16Bytes(counter);
    if (mbedtlsFfiAvailable) {
      try {
        return AesCtr._(
          NativeAesCtr(key: keyBytes, counter: counterBytes),
          null,
        );
      } on MbedTlsException {
        // Native setup failed unexpectedly; fall back to pointycastle below.
      }
    }
    final cipher = CTRStreamCipher(AESEngine())
      ..init(
        // forEncryption is irrelevant for CTR but required by the API.
        true,
        ParametersWithIV<KeyParameter>(
          KeyParameter(keyBytes),
          counterBytes,
        ),
      );
    return AesCtr._(null, cipher);
  }

  /// XOR [data] with the next bytes of the keystream and return the result.
  /// Advances the internal counter so subsequent calls continue the stream.
  Uint8List process(Uint8List data) {
    final native = _native;
    if (native != null) return native.process(data);
    return _fallback!.process(data);
  }

  /// Releases the native cipher context if one is held. Optional: an abandoned
  /// instance is reclaimed by a [NativeFinalizer], so existing callers need not
  /// call this.
  void dispose() => _native?.dispose();
}
