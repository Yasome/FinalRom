import 'dart:ffi';
import 'dart:isolate';

import 'package:chdman_ffi/chdman_ffi.dart';

enum ChdAction { create, extract }

class ChdParams {
  final ChdAction action;
  final String inputPath;

  /// For [ChdAction.create] this is the `.chd` output. For [ChdAction.extract]
  /// it is the `.cue` output.
  final String outputPath;

  /// The `.bin` output, used only for [ChdAction.extract].
  final String? outputBinPath;

  /// Tunable chdman options (codecs, threads, hunk size, force).
  final ChdOptions options;

  /// When true and [action] is [ChdAction.create], the input is written as a
  /// DVD CHD (chdman createdvd) instead of a CD CHD. Ignored by extract.
  final bool createDvd;

  /// Address of a native `Int32` progress cell the caller allocated and polls,
  /// or 0 for no progress reporting. Native code writes 0..1000 into it.
  final int progressAddress;

  /// Address of a native `Int32` cancel cell the caller allocated, or 0 for no
  /// cancellation support. The caller stores a non-zero value to request the
  /// native operation abort; native code polls it and returns
  /// [ChdmanResult.errCancelled]. The cell must outlive the FFI call.
  final int cancelAddress;

  final SendPort sendPort;

  ChdParams({
    required this.action,
    required this.inputPath,
    required this.outputPath,
    this.outputBinPath,
    this.options = const ChdOptions(),
    this.createDvd = false,
    this.progressAddress = 0,
    this.cancelAddress = 0,
    required this.sendPort,
  });
}

/// Runs a blocking chdman FFI call off the UI isolate, mirroring
/// [PatchWorker]'s structure. The native CD operations are synchronous, so this
/// is meant to be the entry point of an [Isolate.spawn].
class ChdWorker {
  static Future<void> runChd(ChdParams params) async {
    final progress = params.progressAddress != 0
        ? Pointer<Int32>.fromAddress(params.progressAddress)
        : null;
    final cancel = params.cancelAddress != 0
        ? Pointer<Int32>.fromAddress(params.cancelAddress)
        : null;
    try {
      final int code;
      switch (params.action) {
        case ChdAction.create:
          final createChd =
              params.createDvd ? chdmanCreateDvd : chdmanCreateCd;
          code = createChd(
            params.inputPath,
            params.outputPath,
            options: params.options,
            progress: progress,
            cancel: cancel,
          );
        case ChdAction.extract:
          final binPath = params.outputBinPath;
          if (binPath == null) {
            throw ArgumentError('Extracting a CHD requires outputBinPath.');
          }
          code = chdmanExtractCd(
            params.inputPath,
            params.outputPath,
            binPath,
            options: params.options,
            progress: progress,
            cancel: cancel,
          );
      }

      if (code == ChdmanResult.ok) {
        params.sendPort.send(ChdResult(success: true, path: params.outputPath));
      } else if (code == ChdmanResult.errCancelled) {
        params.sendPort.send(ChdResult(success: false, cancelled: true));
      } else {
        // Fetch the native detail right after the call (same thread) so the
        // generic code message carries the real chdman reason.
        final detail = chdmanLastError();
        final message = _messageForCode(code);
        params.sendPort.send(ChdResult(
          success: false,
          error: detail.isEmpty ? message : '$message: $detail',
        ));
      }
    } catch (error) {
      params.sendPort.send(ChdResult(success: false, error: error.toString()));
    }
  }

  static String _messageForCode(int code) {
    switch (code) {
      case ChdmanResult.errOpenInput:
        return 'Unable to open the input file.';
      case ChdmanResult.errOpenOutput:
        return 'Unable to open the output file.';
      case ChdmanResult.errInvalidInput:
        return 'The input is not a valid CD image / CHD.';
      case ChdmanResult.errOutputExists:
        return 'The output file already exists.';
      case ChdmanResult.errCodec:
        return 'A CHD codec error occurred.';
      case ChdmanResult.errInternal:
        return 'chdman failed with an internal error.';
      case ChdmanResult.errLibUnavailable:
        return 'CHD support is not built. Vendor the MAME chd sources into '
            'packages/chdman_ffi/src/chd and rebuild.';
      default:
        return 'chdman failed with error code $code.';
    }
  }
}

class ChdResult {
  final bool success;
  final String? path;
  final String? error;

  /// True when the operation stopped because cancellation was requested, rather
  /// than failing. [error] is null in that case.
  final bool cancelled;

  ChdResult({
    required this.success,
    this.path,
    this.error,
    this.cancelled = false,
  });
}
