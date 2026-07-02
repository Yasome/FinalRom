// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Final ROM';

  @override
  String get tabSingleFile => 'Single File';

  @override
  String get tabThreeDs => '3DS';

  @override
  String get tabBatchMode => 'Batch Mode';

  @override
  String get tabPatcher => 'Patcher';

  @override
  String get tabHasher => 'Hasher';

  @override
  String get btnDecrypt => 'Decrypt';

  @override
  String get btnEncrypt => 'Encrypt';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnClearQueue => 'Clear';

  @override
  String get btnBrowse => 'Browse';

  @override
  String get btnBrowseFolder => 'Folder';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get trimPadding => 'Trim trailing padding (Decrypt)';

  @override
  String get trimPaddingDesc =>
      'Removes empty 0xFF padding from the end of the file, saving space.';

  @override
  String get outputHandling => 'Output handling';

  @override
  String get outputHandlingNewFile => 'Create a new file';

  @override
  String get outputHandlingOverwrite => 'Overwrite original (Destructive)';

  @override
  String get outputLocation => 'Output location';

  @override
  String get outputLocationNextToSource => 'Next to source file';

  @override
  String get outputLocationCustom => 'Custom folder';

  @override
  String get outputLocationAppDocs => 'Device folder (app storage)';

  @override
  String get conflictBehavior => 'If output exists';

  @override
  String get conflictAsk => 'Ask';

  @override
  String get conflictOverwrite => 'Overwrite';

  @override
  String get conflictRename => 'Auto-rename';

  @override
  String get parallelism => 'Parallelism';

  @override
  String get parallelismDesc => 'Files processed at once';

  @override
  String get themeMode => 'Appearance';

  @override
  String get themeSystem => 'System Default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get dynamicColor => 'Use Material You dynamic color';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System Default';

  @override
  String get statusIdle => 'Idle';

  @override
  String get statusDone => 'Done';

  @override
  String get statusError => 'Error';

  @override
  String get statusSaving => 'Saving...';

  @override
  String statusFileSelected(String size) {
    return '$size MiB';
  }

  @override
  String trimMessage(String saved) {
    return 'Trimmed $saved bytes of padding';
  }

  @override
  String batchSummary(int success, int failed, String time) {
    return '$success succeeded, $failed failed (in ${time}s)';
  }

  @override
  String batchProgress(int current, int total) {
    return 'Processed $current of $total';
  }

  @override
  String get errNoFileSelected => 'No file selected';

  @override
  String get errOutputFolderNotSelected => 'Output folder not selected';

  @override
  String get confirmOverwriteTitle => 'Overwrite Original?';

  @override
  String get confirmOverwriteContent =>
      'This will destructively overwrite the original ROM file. Are you sure you want to continue?';

  @override
  String get btnYes => 'Yes';

  @override
  String get btnNo => 'No';

  @override
  String get errInvalidRom => 'Invalid 3DS ROM';

  @override
  String get fileConflictTitle => 'File already exists';

  @override
  String fileConflictContent(String filename) {
    return 'The file $filename already exists. What would you like to do?';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionOverwrite => 'Overwrite';

  @override
  String get actionRename => 'Rename';

  @override
  String queueFileProgress(int current, int total) {
    return 'File $current of $total';
  }

  @override
  String queueDoneSummary(int ok, int total) {
    return '$ok of $total done';
  }

  @override
  String queueFailuresSummary(int failed, int total) {
    return '$failed of $total failed';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutContent =>
      'This app runs completely offline and collects no personal data.';

  @override
  String get dragDropHintSingle => 'Drop .3ds ROM file here';

  @override
  String get dragDropHintBatch => 'Drop .3ds ROM files here';

  @override
  String get dragDropHintRom => 'Drop ROM file here';

  @override
  String get dragDropHintPatch => 'Drop patch file here';

  @override
  String get dragDropHintHash => 'Drop file here to hash';

  @override
  String get dragDropOnly3ds => 'Only .3ds files are supported';

  @override
  String get dragDropSubtext => 'Release mouse to drop';

  @override
  String get romFile => 'Base ROM File';

  @override
  String get patchFile =>
      'Patch File (.ips, .ups, .bps, .ppf, .aps, .ebp, .dps, .xdelta)';

  @override
  String get btnBrowseRom => 'Browse ROM';

  @override
  String get btnBrowsePatch => 'Browse Patch';

  @override
  String get btnPatch => 'Apply Patch';

  @override
  String get errNoPatchSelected => 'No patch selected';

  @override
  String get statusPatching => 'Applying patch...';

  @override
  String get fileToHash => 'File to Hash';

  @override
  String get statusHashing => 'Calculating hashes...';

  @override
  String get ignoreChecksum => 'Ignore checksum';

  @override
  String get ignoreChecksumSubtitle => 'Skip ROM and patch verification';

  @override
  String get errUnsupportedPatch => 'Unsupported patch format';

  @override
  String patchReportFormat(String format) {
    return 'Format: $format';
  }

  @override
  String get patchReportNoChecksums =>
      'This format has no embedded checksums to verify.';

  @override
  String get checkOutcomePassed => 'Passed';

  @override
  String get checkOutcomeSkipped => 'Skipped';

  @override
  String get tabChd => 'CHD';

  @override
  String get tabSwitch => 'Switch';

  @override
  String get chdCreate => 'Create CHD';

  @override
  String get chdExtract => 'Extract CHD';

  @override
  String get btnCreate => 'Create';

  @override
  String get btnExtract => 'Extract';

  @override
  String get btnMerge => 'Merge';

  @override
  String get btnUnmerge => 'Unmerge';

  @override
  String get btnCompress => 'Compress';

  @override
  String get btnDecompress => 'Decompress';

  @override
  String get chdCreateHint => 'Drop .cue or .iso file here';

  @override
  String get chdExtractHint => 'Drop .chd file here';

  @override
  String get chdDiscType => 'Disc type';

  @override
  String get chdDiscTypeCd => 'CD';

  @override
  String get chdDiscTypeDvd => 'DVD';

  @override
  String get chdBinNeedsCue =>
      'A .bin is a raw track — add its .cue sheet instead.';

  @override
  String get switchMergeTab => 'Merge';

  @override
  String get switchSplitTab => 'Split';

  @override
  String get switchCompressTab => 'Compress';

  @override
  String get switchDecompressTab => 'Decompress';

  @override
  String get switchMergeHint => 'Drop base and update .nsp / .xci files here';

  @override
  String get switchUnmergeHint => 'Drop a merged .nsp file here';

  @override
  String get switchCompressHint => 'Drop .nsp file here';

  @override
  String get switchDecompressHint => 'Drop .nsz file here';

  @override
  String get switchKeysRequired => 'prod.keys is required for this operation';

  @override
  String get keysFile => 'prod.keys File';

  @override
  String get btnBrowseKeys => 'Browse Keys';

  @override
  String get compressionLevel => 'Compression Level';

  @override
  String get statusCompressing => 'Compressing...';

  @override
  String get statusExtracting => 'Extracting...';

  @override
  String get statusMerging => 'Merging...';

  @override
  String get statusUnmerging => 'Unmerging...';

  @override
  String get statusDecompressing => 'Decompressing...';

  @override
  String unmergeSavedMessage(int count, String dir) {
    return 'Wrote $count NSP files to $dir';
  }

  @override
  String unmergeMissingNcaWarning(int count) {
    return '$count title(s) reference NCAs missing from the source NSP';
  }

  @override
  String get patchCompatibilityChecking => 'Verifying ROM compatibility...';

  @override
  String get patchCompatibilityCompatible =>
      'Patch is compatible with the selected ROM';

  @override
  String get patchCompatibilityIncompatible =>
      'Warning: ROM checksum does not match. This patch may be incompatible.';

  @override
  String get patchCompatibilityUnverifiable =>
      'This patch format does not support pre-verification';

  @override
  String get btnShare => 'Share';

  @override
  String savedToFile(String name) {
    return 'Saved: $name';
  }

  @override
  String get alreadyDecryptedMessage =>
      'Already decrypted — no new file created';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheSubtitle => 'Remove temporary and cached files';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get btnSave => 'Save';

  @override
  String get btnShowInFolder => 'Show in folder';

  @override
  String get statusCancelling => 'Cancelling…';

  @override
  String get errInvalidFileType => 'Invalid file type for the selected action';

  @override
  String get keysRequired3ds => '3dskeys.txt is required for this operation';

  @override
  String copiedToClipboard(String label) {
    return 'Copied $label to clipboard';
  }

  @override
  String get chdCodecsTitle => 'Compression codecs';

  @override
  String get chdCodecsHelper => 'Comma-separated: cdlz, cdzl, cdfl, cdzs, none';

  @override
  String get chdHunkTitle => 'Hunk size (bytes)';

  @override
  String get chdHunkHelper => 'Leave empty for default';

  @override
  String get tabArchive => 'Archive';

  @override
  String get archiveFormat => 'Format';

  @override
  String get archiveCompressHint => 'Drop any file here to compress';

  @override
  String get archiveDecompressHint => 'Drop a .zip / .gz / .zst file here';
}
