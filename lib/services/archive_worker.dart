import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:archive_ffi/archive_ffi.dart';

import 'archive_service.dart';

enum ArchiveAction { compress, decompress }

class ArchiveParams {
  final ArchiveAction action;
  final String inputPath;

  /// For [ArchiveAction.compress] this is the produced archive. For
  /// [ArchiveAction.decompress] it is the restored file (gzip/zstd) or the
  /// destination directory (zip/7z).
  final String outputPath;

  final ArchiveFormat format;

  /// Compression level, or null for the format's default.
  final int? level;

  /// Address of a native `Int32` progress cell the caller allocated and polls,
  /// or 0 for no reporting. The native side writes 0..1000 (per-mille) into it.
  final int progressAddress;

  /// Address of a native `Int32` cancel cell the caller allocated, or 0 for no
  /// cancellation. The caller stores a non-zero value to request an abort; the
  /// native side polls it and stops at the next checkpoint.
  final int cancelAddress;

  final SendPort sendPort;

  ArchiveParams({
    required this.action,
    required this.inputPath,
    required this.outputPath,
    required this.format,
    this.level,
    this.progressAddress = 0,
    this.cancelAddress = 0,
    required this.sendPort,
  });
}

class ArchiveResult {
  final bool success;
  final String? path;
  final String? error;

  /// True when the operation stopped because cancellation was requested rather
  /// than failing. [error] is null in that case.
  final bool cancelled;

  ArchiveResult({
    required this.success,
    this.path,
    this.error,
    this.cancelled = false,
  });
}

/// Runs a blocking libarchive FFI call off the UI isolate, mirroring
/// [ChdWorker]. Progress and cancellation flow through the shared native cells
/// the bloc allocated; the addresses are passed straight to the native call.
class ArchiveWorker {
  static Future<void> runArchive(ArchiveParams params) async {
    final progress = params.progressAddress != 0
        ? Pointer<Int32>.fromAddress(params.progressAddress)
        : null;
    final cancel = params.cancelAddress != 0
        ? Pointer<Int32>.fromAddress(params.cancelAddress)
        : null;

    try {
      final int code;
      switch (params.action) {
        case ArchiveAction.compress:
          code = archiveCompress(
            inputPath: params.inputPath,
            outputPath: params.outputPath,
            format: ArchiveService.ffiFormatCode(params.format),
            level: params.level ?? 0,
            progress: progress,
            cancel: cancel,
          );
        case ArchiveAction.decompress:
          code = archiveExtract(
            inputPath: params.inputPath,
            outputPath: params.outputPath,
            isContainer: ArchiveService.isContainer(params.format),
            progress: progress,
            cancel: cancel,
          );
      }

      if (code == ArchiveFfiResult.ok) {
        params.sendPort
            .send(ArchiveResult(success: true, path: params.outputPath));
      } else if (code == ArchiveFfiResult.errCancelled) {
        await _cleanupPartial(params);
        params.sendPort.send(ArchiveResult(success: false, cancelled: true));
      } else {
        await _cleanupPartial(params);
        params.sendPort.send(
            ArchiveResult(success: false, error: ArchiveService.messageForCode(code)));
      }
    } catch (error) {
      params.sendPort.send(ArchiveResult(success: false, error: error.toString()));
    }
  }

  /// Removes a partial extraction directory after a failed/cancelled container
  /// extract. The native side already deletes partial single-file outputs
  /// (compress targets and raw gzip/zstd restores), so this only covers the
  /// directory case it intentionally leaves behind.
  static Future<void> _cleanupPartial(ArchiveParams params) async {
    if (params.action != ArchiveAction.decompress ||
        !ArchiveService.isContainer(params.format)) {
      return;
    }
    try {
      final dir = Directory(params.outputPath);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup of a partial extraction.
    }
  }
}
