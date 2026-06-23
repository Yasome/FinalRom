import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, String>? _dotenv;

Map<String, String> _loadDotenv() {
  final override = Platform.environment['DOTENV']?.trim();
  final file = File(override != null && override.isNotEmpty ? override : '.env');
  if (!file.existsSync()) return const {};

  final entries = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf('=');
    if (separator <= 0) continue;
    final key = line.substring(0, separator).trim();
    var value = line.substring(separator + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    entries[key] = value;
  }
  return entries;
}

String? envPath(String name) {
  // Real environment variables take precedence over the .env file.
  final fromEnvironment = Platform.environment[name]?.trim();
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return fromEnvironment;
  }
  final fromFile = (_dotenv ??= _loadDotenv())[name]?.trim();
  return (fromFile == null || fromFile.isEmpty) ? null : fromFile;
}

Map<String, String>? requireInputs(Map<String, String> vars) {
  final resolved = <String, String>{};
  final problems = <String>[];
  vars.forEach((name, description) {
    final path = envPath(name);
    if (path == null) {
      problems.add('$name (unset) — $description');
    } else if (!File(path).existsSync()) {
      problems.add('$name=$path (file not found) — $description');
    } else {
      resolved[name] = path;
    }
  });
  if (problems.isNotEmpty) {
    markTestSkipped('Missing test inputs:\n  ${problems.join('\n  ')}');
    return null;
  }
  return resolved;
}

Directory? requireDest(String name) {
  final path = envPath(name);
  if (path == null) {
    markTestSkipped('Missing destination dir: $name (unset)');
    return null;
  }
  return Directory(path)..createSync(recursive: true);
}
