import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import '../patcher/patcher_factory.dart';

class FileService {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Returns true if in-place overwrite is supported on this platform.
  static bool get supportsInPlace => isDesktop;

  /// Picks one or more files. On desktop the dialog is filtered to
  /// [allowedExtensions] (defaults to `3ds`); on mobile the system picker
  /// offers all files (its custom-extension filtering is unreliable), and the
  /// caller is expected to filter the returned paths by extension.
  static Future<List<String>> pickFiles({
    required bool allowMultiple,
    List<String> allowedExtensions = const ['3ds'],
  }) async {
    if (isMobile) {
      // Android uses AndroidFilePicker directly in the UI layer.
      return [];
    }
    final result = await FilePicker.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result != null) {
      return result.paths.whereType<String>().toList();
    }
    return [];
  }

  /// Picks one or more files of any type (used by the general archive
  /// compressor, which accepts arbitrary input). Returns an empty list on
  /// mobile, where the Android picker is used from the UI layer instead.
  static Future<List<String>> pickAnyFiles({bool allowMultiple = true}) async {
    if (isMobile) return [];
    final result = await FilePicker.pickFiles(allowMultiple: allowMultiple);
    if (result != null) {
      return result.paths.whereType<String>().toList();
    }
    return [];
  }

  static Future<String?> pickPatchFile() async {
    if (isMobile) {
      return null;
    }
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: PatcherFactory.supportedExtensions.toList(),
    );
    return result?.paths.firstWhere((p) => p != null, orElse: () => null);
  }

  static Future<String?> pickAnyFile() async {
    if (isMobile) return null;
    final result = await FilePicker.pickFiles(allowMultiple: false);
    return result?.paths.firstWhere((p) => p != null, orElse: () => null);
  }

  static Future<List<String>> pickFolderAndScan() async {
    if (isMobile) return [];
    final folderPath = await FilePicker.getDirectoryPath();
    if (folderPath == null) return [];

    final dir = Directory(folderPath);
    if (!await dir.exists()) return [];

    final files = await dir.list(recursive: false).toList();
    return files
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.3ds')
        .map((file) => file.path)
        .toList();
  }

  static Future<String?> pickOutputFolder() async {
    if (isMobile) return null;
    return await FilePicker.getDirectoryPath();
  }

  static Future<String> getAppDocumentsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Directory mobile outputs are written to. On Android this is the app's
  /// external-storage files dir (`Android/data/<pkg>/files`), which is browsable
  /// in file managers and over USB without any storage permission. Falls back to
  /// the (private) app documents dir if external storage is unavailable.
  static Future<String> getMobileOutputDirectory() async {
    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          await external.create(recursive: true);
          return external.path;
        }
      } catch (_) {
        // Fall through to the documents dir below.
      }
    }
    return getAppDocumentsDirectory();
  }

  /// Opens the system share sheet for [filePath]. Triggered explicitly by the
  /// user (e.g. a "Share" action), never automatically.
  static Future<void> shareFile(String filePath) async {
    if (!isMobile) return;
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(filePath)]);
  }

  /// Prefix shared by every scratch directory this app creates, so they can be
  /// found and purged later.
  static const String _tempDirPrefix = 'tds_scratch_';

  /// Root directory for large scratch files (NSZ intermediate `.ncz`/`.nca`).
  /// On Android this prefers the external cache (typically far roomier than the
  /// internal cache, which a multi-GB game can overflow); otherwise the system
  /// temp dir. path_provider uses platform channels, so this must run on the
  /// main isolate and the resolved path be handed to background isolates.
  static Future<String> _getTempRoot() async {
    if (Platform.isAndroid) {
      try {
        final externalCaches = await getExternalCacheDirectories();
        if (externalCaches != null && externalCaches.isNotEmpty) {
          return externalCaches.first.path;
        }
      } catch (_) {
        // Fall through to the system temp dir below.
      }
    }
    return Directory.systemTemp.path;
  }

  /// Creates and returns a unique scratch directory for one NSZ run. The caller
  /// (a bloc on the main isolate) passes the path to the worker and deletes the
  /// directory when the run ends — including on cancel, where the worker's own
  /// cleanup is skipped because the isolate is killed.
  static Future<String> createScratchDir() async {
    final root = await _getTempRoot();
    final dir = Directory(
        p.join(root, '$_tempDirPrefix${DateTime.now().microsecondsSinceEpoch}'));
    await dir.create(recursive: true);
    return dir.path;
  }

  /// Best-effort deletion of a single scratch directory.
  static Future<void> deleteScratchDir(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort: a leftover dir is purged on next launch / Clear cache.
    }
  }

  /// Removes any scratch directories left behind by previous runs (e.g. after a
  /// crash or a killed isolate). Safe to call on startup.
  static Future<void> purgeScratchDirs() async {
    try {
      final root = Directory(await _getTempRoot());
      if (!await root.exists()) return;
      await for (final entity in root.list()) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith(_tempDirPrefix)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            // Skip ones still in use.
          }
        }
      }
    } catch (_) {
      // Best-effort.
    }
  }

  static Future<void> clearCaches() async {
    await purgeScratchDirs();
    // Desktop temporary files clearing can be done here if supported,
    // but file_picker on mobile is bypassed so no temp files from it exist there.
  }

  static Future<String> generateUniqueOutputPath(String baseFolder, String baseName, String extension) async {
    int counter = 1;
    String newPath = p.join(baseFolder, '$baseName$extension');
    while (await File(newPath).exists()) {
      newPath = p.join(baseFolder, '${baseName}_$counter$extension');
      counter++;
    }
    return newPath;
  }

  /// Resolves the file paths from a desktop drag-and-drop. Each entry in
  /// [droppedPaths] is a file path handed over by `desktop_drop`; a dropped
  /// directory is expanded to the `.3ds` files it directly contains, while any
  /// other path is passed through as-is.
  static Future<List<String>> handleDroppedItems(List<String> droppedPaths) async {
    final paths = <String>[];

    for (final path in droppedPaths) {
      if (await FileSystemEntity.isDirectory(path)) {
        final dir = Directory(path);
        try {
          final files = await dir.list(recursive: false).toList();
          final dsFiles = files
              .whereType<File>()
              .where((file) => p.extension(file.path).toLowerCase() == '.3ds')
              .map((file) => file.path)
              .toList();
          paths.addAll(dsFiles);
        } catch (e) {
          // Ignore listing errors
        }
      } else {
        paths.add(path);
      }
    }
    return paths;
  }

  /// Opens the directory containing [filePath] in the system file manager,
  /// with the file selected/highlighted on desktop platforms.
  static Future<void> openDirectory(String filePath) async {
    if (!isDesktop) return;
    try {
      final file = File(filePath).absolute;
      final dir = file.parent;
      if (!dir.existsSync()) return;

      if (Platform.isWindows) {
        final winPath = file.path.replaceAll('/', '\\');
        if (file.existsSync()) {
          // explorer.exe needs `/select,<path>` as a SINGLE argument — passing
          // them as two argv entries makes Windows join them with a space, so
          // explorer ignores the selection and just opens the default folder.
          await Process.run('explorer.exe', ['/select,$winPath']);
        } else {
          await Process.run('explorer.exe', [dir.path.replaceAll('/', '\\')]);
        }
      } else if (Platform.isMacOS) {
        if (file.existsSync()) {
          await Process.run('open', ['-R', file.path]);
        } else {
          await Process.run('open', [dir.path]);
        }
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir.path]);
      }
    } catch (e) {
      // Ignore
    }
  }
}
