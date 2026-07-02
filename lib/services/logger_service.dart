import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'file_service.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  static LoggerService get instance => _instance;

  File? _logFile;

  LoggerService._internal();

  Future<void> init() async {
    Logger.root.level = Level.ALL;
    
    try {
      final docDir = await FileService.getAppDocumentsDirectory();
      _logFile = File(p.join(docDir, 'final_rom_app.log'));
      
      // If the file is too large (e.g. > 5MB), clear it or rename it
      if (await _logFile!.exists() && await _logFile!.length() > 5 * 1024 * 1024) {
        await _logFile!.delete();
      }
    } catch (e) {
      // Ignored if file system is inaccessible
    }

    Logger.root.onRecord.listen((record) {
      final buffer = StringBuffer('${record.level.name}: ${record.time}: ${_redactPaths(record.message)}');
      if (record.error != null) {
        buffer.write('\n  error: ${_redactPaths(record.error.toString())}');
      }
      if (record.stackTrace != null) {
        buffer.write('\n${record.stackTrace}');
      }
      buffer.write('\n');
      final message = buffer.toString();

      // Print to console in debug mode
      stdout.write(message);
      
      // Write to log file
      if (_logFile != null) {
        try {
          _logFile!.writeAsStringSync(message, mode: FileMode.append);
        } catch (e) {
          // Ignore
        }
      }
    });
  }

  static final RegExp _pathPattern = RegExp(
    r'(?:[a-zA-Z]:[\\/]|[\\/])[^\s"' "'" r']*[\\/][^\s"' "'" r']+',
  );

  String _redactPaths(String message) {
    return message.replaceAllMapped(_pathPattern, (match) => p.basename(match.group(0)!));
  }

  Future<String?> getLogFilePath() async {
    if (_logFile != null && await _logFile!.exists()) {
      return _logFile!.path;
    }
    return null;
  }
}
