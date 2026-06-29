import 'package:archive_ffi/archive_ffi.dart';

/// Generic archive formats the app can compress to / decompress from, all
/// handled by the native libarchive backend ([archive_ffi]).
enum ArchiveFormat { zip, gzip, zstd, sevenZip }

/// Format metadata and native-result mapping for the Archive feature. The actual
/// compression/extraction lives in the native libarchive plugin; this class only
/// describes formats and turns native result codes into user-facing messages.
class ArchiveService {
  static const Map<ArchiveFormat, String> _extensions = {
    ArchiveFormat.zip: '.zip',
    ArchiveFormat.gzip: '.gz',
    ArchiveFormat.zstd: '.zst',
    ArchiveFormat.sevenZip: '.7z',
  };

  /// The output extension produced when compressing to [format].
  static String extensionFor(ArchiveFormat format) => _extensions[format]!;

  /// Infers the format of an existing archive from its file name, or null when
  /// the extension is not a supported archive.
  static ArchiveFormat? formatForArchive(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.zip')) return ArchiveFormat.zip;
    if (lower.endsWith('.gz')) return ArchiveFormat.gzip;
    if (lower.endsWith('.zst')) return ArchiveFormat.zstd;
    if (lower.endsWith('.7z')) return ArchiveFormat.sevenZip;
    return null;
  }

  /// True when [format] extracts into a directory (an archive container) rather
  /// than restoring a single file.
  static bool isContainer(ArchiveFormat format) =>
      format == ArchiveFormat.zip || format == ArchiveFormat.sevenZip;

  /// Maps [format] to the native `ARCHIVE_FFI_FORMAT_*` selector.
  static int ffiFormatCode(ArchiveFormat format) {
    switch (format) {
      case ArchiveFormat.zip:
        return ArchiveFfiFormat.zip;
      case ArchiveFormat.gzip:
        return ArchiveFfiFormat.gzip;
      case ArchiveFormat.zstd:
        return ArchiveFfiFormat.zstd;
      case ArchiveFormat.sevenZip:
        return ArchiveFfiFormat.sevenZip;
    }
  }

  /// Turns a native [ArchiveFfiResult] code into a user-facing error message.
  static String messageForCode(int code) {
    switch (code) {
      case ArchiveFfiResult.errOpenInput:
        return 'Unable to open the input file.';
      case ArchiveFfiResult.errOpenOutput:
        return 'Unable to open the output location.';
      case ArchiveFfiResult.errFormat:
        return 'The archive is corrupt or its format is unsupported.';
      case ArchiveFfiResult.errInternal:
        return 'The archive operation failed.';
      case ArchiveFfiResult.errLibUnavailable:
        return 'Archive support is not built. Vendor the libarchive sources into '
            'packages/archive_ffi/src and rebuild.';
      default:
        return 'Archive failed with error code $code.';
    }
  }
}
