import 'dart:io';

enum NativeHashAlgo { md5, sha1, sha256 }

extension on NativeHashAlgo {
  int get hexLength {
    switch (this) {
      case NativeHashAlgo.md5:
        return 32;
      case NativeHashAlgo.sha1:
        return 40;
      case NativeHashAlgo.sha256:
        return 64;
    }
  }
}

class NativeHasher {
  static bool get supported =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  static Future<Map<NativeHashAlgo, String?>> computeConcurrently(
    String filePath,
    Set<NativeHashAlgo> algos,
  ) async {
    final ordered = algos.toList();
    final results = await Future.wait(
      ordered.map((algo) => compute(algo, filePath)),
    );
    return {for (var i = 0; i < ordered.length; i++) ordered[i]: results[i]};
  }

  static Future<String?> compute(NativeHashAlgo algo, String filePath) async {
    final command = _command(algo, filePath);
    if (command == null) return null;
    try {
      final result = await Process.run(command.first, command.sublist(1));
      if (result.exitCode != 0) return null;
      return _parse(algo, result.stdout.toString());
    } catch (_) {
      return null;
    }
  }

  static List<String>? _command(NativeHashAlgo algo, String filePath) {
    if (Platform.isLinux) {
      const tool = {
        NativeHashAlgo.md5: 'md5sum',
        NativeHashAlgo.sha1: 'sha1sum',
        NativeHashAlgo.sha256: 'sha256sum',
      };
      return [tool[algo]!, filePath];
    }
    if (Platform.isMacOS) {
      return ['openssl', 'dgst', '-${_opensslName(algo)}', '-r', filePath];
    }
    if (Platform.isWindows) {
      return ['certutil', '-hashfile', filePath, _certutilName(algo)];
    }
    return null;
  }

  static String _opensslName(NativeHashAlgo algo) {
    switch (algo) {
      case NativeHashAlgo.md5:
        return 'md5';
      case NativeHashAlgo.sha1:
        return 'sha1';
      case NativeHashAlgo.sha256:
        return 'sha256';
    }
  }

  static String _certutilName(NativeHashAlgo algo) {
    switch (algo) {
      case NativeHashAlgo.md5:
        return 'MD5';
      case NativeHashAlgo.sha1:
        return 'SHA1';
      case NativeHashAlgo.sha256:
        return 'SHA256';
    }
  }

  static String? _parse(NativeHashAlgo algo, String output) {
    if (Platform.isWindows) return _parseCertutil(algo, output);
    return _parseFirstToken(algo, output);
  }

  static String? _parseFirstToken(NativeHashAlgo algo, String output) {
    final token = output.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return _validate(algo, token);
  }

  // certutil brackets the digest with a header and status line; its casing and
  // spacing vary by Windows version.
  static String? _parseCertutil(NativeHashAlgo algo, String output) {
    for (final line in output.split('\n')) {
      final candidate = line.replaceAll(RegExp(r'\s'), '').toLowerCase();
      final validated = _validate(algo, candidate);
      if (validated != null) return validated;
    }
    return null;
  }

  static String? _validate(NativeHashAlgo algo, String hex) {
    if (hex.length != algo.hexLength) return null;
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(hex)) return null;
    return hex;
  }
}
