import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Final ROM'**
  String get appTitle;

  /// No description provided for @tabSingleFile.
  ///
  /// In en, this message translates to:
  /// **'Single File'**
  String get tabSingleFile;

  /// No description provided for @tabThreeDs.
  ///
  /// In en, this message translates to:
  /// **'3DS'**
  String get tabThreeDs;

  /// No description provided for @tabBatchMode.
  ///
  /// In en, this message translates to:
  /// **'Batch Mode'**
  String get tabBatchMode;

  /// No description provided for @tabPatcher.
  ///
  /// In en, this message translates to:
  /// **'Patcher'**
  String get tabPatcher;

  /// No description provided for @tabHasher.
  ///
  /// In en, this message translates to:
  /// **'Hasher'**
  String get tabHasher;

  /// No description provided for @btnDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Decrypt'**
  String get btnDecrypt;

  /// No description provided for @btnEncrypt.
  ///
  /// In en, this message translates to:
  /// **'Encrypt'**
  String get btnEncrypt;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnClearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get btnClearQueue;

  /// No description provided for @btnBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get btnBrowse;

  /// No description provided for @btnBrowseFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get btnBrowseFolder;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @trimPadding.
  ///
  /// In en, this message translates to:
  /// **'Trim trailing padding (Decrypt)'**
  String get trimPadding;

  /// No description provided for @trimPaddingDesc.
  ///
  /// In en, this message translates to:
  /// **'Removes empty 0xFF padding from the end of the file, saving space.'**
  String get trimPaddingDesc;

  /// No description provided for @outputHandling.
  ///
  /// In en, this message translates to:
  /// **'Output handling'**
  String get outputHandling;

  /// No description provided for @outputHandlingNewFile.
  ///
  /// In en, this message translates to:
  /// **'Create a new file'**
  String get outputHandlingNewFile;

  /// No description provided for @outputHandlingOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite original (Destructive)'**
  String get outputHandlingOverwrite;

  /// No description provided for @outputLocation.
  ///
  /// In en, this message translates to:
  /// **'Output location'**
  String get outputLocation;

  /// No description provided for @outputLocationNextToSource.
  ///
  /// In en, this message translates to:
  /// **'Next to source file'**
  String get outputLocationNextToSource;

  /// No description provided for @outputLocationCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom folder'**
  String get outputLocationCustom;

  /// No description provided for @outputLocationAppDocs.
  ///
  /// In en, this message translates to:
  /// **'Device folder (app storage)'**
  String get outputLocationAppDocs;

  /// No description provided for @conflictBehavior.
  ///
  /// In en, this message translates to:
  /// **'If output exists'**
  String get conflictBehavior;

  /// No description provided for @conflictAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get conflictAsk;

  /// No description provided for @conflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get conflictOverwrite;

  /// No description provided for @conflictRename.
  ///
  /// In en, this message translates to:
  /// **'Auto-rename'**
  String get conflictRename;

  /// No description provided for @parallelism.
  ///
  /// In en, this message translates to:
  /// **'Parallelism'**
  String get parallelism;

  /// No description provided for @parallelismDesc.
  ///
  /// In en, this message translates to:
  /// **'Files processed at once'**
  String get parallelismDesc;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @dynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Use Material You dynamic color'**
  String get dynamicColor;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get statusIdle;

  /// No description provided for @statusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statusDone;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// No description provided for @statusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get statusSaving;

  /// No description provided for @statusFileSelected.
  ///
  /// In en, this message translates to:
  /// **'{size} MiB'**
  String statusFileSelected(String size);

  /// No description provided for @trimMessage.
  ///
  /// In en, this message translates to:
  /// **'Trimmed {saved} bytes of padding'**
  String trimMessage(String saved);

  /// No description provided for @batchSummary.
  ///
  /// In en, this message translates to:
  /// **'{success} succeeded, {failed} failed (in {time}s)'**
  String batchSummary(int success, int failed, String time);

  /// No description provided for @batchProgress.
  ///
  /// In en, this message translates to:
  /// **'Processed {current} of {total}'**
  String batchProgress(int current, int total);

  /// No description provided for @errNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get errNoFileSelected;

  /// No description provided for @errOutputFolderNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Output folder not selected'**
  String get errOutputFolderNotSelected;

  /// No description provided for @confirmOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite Original?'**
  String get confirmOverwriteTitle;

  /// No description provided for @confirmOverwriteContent.
  ///
  /// In en, this message translates to:
  /// **'This will destructively overwrite the original ROM file. Are you sure you want to continue?'**
  String get confirmOverwriteContent;

  /// No description provided for @btnYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get btnYes;

  /// No description provided for @btnNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get btnNo;

  /// No description provided for @errInvalidRom.
  ///
  /// In en, this message translates to:
  /// **'Invalid 3DS ROM'**
  String get errInvalidRom;

  /// No description provided for @fileConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'File already exists'**
  String get fileConflictTitle;

  /// No description provided for @fileConflictContent.
  ///
  /// In en, this message translates to:
  /// **'The file {filename} already exists. What would you like to do?'**
  String fileConflictContent(String filename);

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get actionOverwrite;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @queueFileProgress.
  ///
  /// In en, this message translates to:
  /// **'File {current} of {total}'**
  String queueFileProgress(int current, int total);

  /// No description provided for @queueDoneSummary.
  ///
  /// In en, this message translates to:
  /// **'{ok} of {total} done'**
  String queueDoneSummary(int ok, int total);

  /// No description provided for @queueFailuresSummary.
  ///
  /// In en, this message translates to:
  /// **'{failed} of {total} failed'**
  String queueFailuresSummary(int failed, int total);

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutContent.
  ///
  /// In en, this message translates to:
  /// **'This app runs completely offline and collects no personal data.'**
  String get aboutContent;

  /// No description provided for @dragDropHintSingle.
  ///
  /// In en, this message translates to:
  /// **'Drop .3ds ROM file here'**
  String get dragDropHintSingle;

  /// No description provided for @dragDropHintBatch.
  ///
  /// In en, this message translates to:
  /// **'Drop .3ds ROM files here'**
  String get dragDropHintBatch;

  /// No description provided for @dragDropHintRom.
  ///
  /// In en, this message translates to:
  /// **'Drop ROM file here'**
  String get dragDropHintRom;

  /// No description provided for @dragDropHintPatch.
  ///
  /// In en, this message translates to:
  /// **'Drop patch file here'**
  String get dragDropHintPatch;

  /// No description provided for @dragDropHintHash.
  ///
  /// In en, this message translates to:
  /// **'Drop file here to hash'**
  String get dragDropHintHash;

  /// No description provided for @dragDropOnly3ds.
  ///
  /// In en, this message translates to:
  /// **'Only .3ds files are supported'**
  String get dragDropOnly3ds;

  /// No description provided for @dragDropSubtext.
  ///
  /// In en, this message translates to:
  /// **'Release mouse to drop'**
  String get dragDropSubtext;

  /// No description provided for @romFile.
  ///
  /// In en, this message translates to:
  /// **'Base ROM File'**
  String get romFile;

  /// No description provided for @patchFile.
  ///
  /// In en, this message translates to:
  /// **'Patch File (.ips, .ups, .bps, .ppf, .aps, .ebp, .dps, .xdelta)'**
  String get patchFile;

  /// No description provided for @btnBrowseRom.
  ///
  /// In en, this message translates to:
  /// **'Browse ROM'**
  String get btnBrowseRom;

  /// No description provided for @btnBrowsePatch.
  ///
  /// In en, this message translates to:
  /// **'Browse Patch'**
  String get btnBrowsePatch;

  /// No description provided for @btnPatch.
  ///
  /// In en, this message translates to:
  /// **'Apply Patch'**
  String get btnPatch;

  /// No description provided for @errNoPatchSelected.
  ///
  /// In en, this message translates to:
  /// **'No patch selected'**
  String get errNoPatchSelected;

  /// No description provided for @statusPatching.
  ///
  /// In en, this message translates to:
  /// **'Applying patch...'**
  String get statusPatching;

  /// No description provided for @fileToHash.
  ///
  /// In en, this message translates to:
  /// **'File to Hash'**
  String get fileToHash;

  /// No description provided for @statusHashing.
  ///
  /// In en, this message translates to:
  /// **'Calculating hashes...'**
  String get statusHashing;

  /// No description provided for @ignoreChecksum.
  ///
  /// In en, this message translates to:
  /// **'Ignore checksum'**
  String get ignoreChecksum;

  /// No description provided for @ignoreChecksumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Skip ROM and patch verification'**
  String get ignoreChecksumSubtitle;

  /// No description provided for @errUnsupportedPatch.
  ///
  /// In en, this message translates to:
  /// **'Unsupported patch format'**
  String get errUnsupportedPatch;

  /// No description provided for @patchReportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: {format}'**
  String patchReportFormat(String format);

  /// No description provided for @patchReportNoChecksums.
  ///
  /// In en, this message translates to:
  /// **'This format has no embedded checksums to verify.'**
  String get patchReportNoChecksums;

  /// No description provided for @checkOutcomePassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get checkOutcomePassed;

  /// No description provided for @checkOutcomeSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get checkOutcomeSkipped;

  /// No description provided for @tabChd.
  ///
  /// In en, this message translates to:
  /// **'CHD'**
  String get tabChd;

  /// No description provided for @tabSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get tabSwitch;

  /// No description provided for @chdCreate.
  ///
  /// In en, this message translates to:
  /// **'Create CHD'**
  String get chdCreate;

  /// No description provided for @chdExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract CHD'**
  String get chdExtract;

  /// No description provided for @btnCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get btnCreate;

  /// No description provided for @btnExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get btnExtract;

  /// No description provided for @btnMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get btnMerge;

  /// No description provided for @btnUnmerge.
  ///
  /// In en, this message translates to:
  /// **'Unmerge'**
  String get btnUnmerge;

  /// No description provided for @btnCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get btnCompress;

  /// No description provided for @btnDecompress.
  ///
  /// In en, this message translates to:
  /// **'Decompress'**
  String get btnDecompress;

  /// No description provided for @chdCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Drop .cue or .iso file here'**
  String get chdCreateHint;

  /// No description provided for @chdExtractHint.
  ///
  /// In en, this message translates to:
  /// **'Drop .chd file here'**
  String get chdExtractHint;

  /// No description provided for @chdDiscType.
  ///
  /// In en, this message translates to:
  /// **'Disc type'**
  String get chdDiscType;

  /// No description provided for @chdDiscTypeCd.
  ///
  /// In en, this message translates to:
  /// **'CD'**
  String get chdDiscTypeCd;

  /// No description provided for @chdDiscTypeDvd.
  ///
  /// In en, this message translates to:
  /// **'DVD'**
  String get chdDiscTypeDvd;

  /// No description provided for @chdBinNeedsCue.
  ///
  /// In en, this message translates to:
  /// **'A .bin is a raw track — add its .cue sheet instead.'**
  String get chdBinNeedsCue;

  /// No description provided for @switchMergeTab.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get switchMergeTab;

  /// No description provided for @switchSplitTab.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get switchSplitTab;

  /// No description provided for @switchCompressTab.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get switchCompressTab;

  /// No description provided for @switchDecompressTab.
  ///
  /// In en, this message translates to:
  /// **'Decompress'**
  String get switchDecompressTab;

  /// No description provided for @switchMergeHint.
  ///
  /// In en, this message translates to:
  /// **'Drop base and update .nsp / .xci files here'**
  String get switchMergeHint;

  /// No description provided for @switchUnmergeHint.
  ///
  /// In en, this message translates to:
  /// **'Drop a merged .nsp file here'**
  String get switchUnmergeHint;

  /// No description provided for @switchCompressHint.
  ///
  /// In en, this message translates to:
  /// **'Drop .nsp file here'**
  String get switchCompressHint;

  /// No description provided for @switchDecompressHint.
  ///
  /// In en, this message translates to:
  /// **'Drop .nsz file here'**
  String get switchDecompressHint;

  /// No description provided for @switchKeysRequired.
  ///
  /// In en, this message translates to:
  /// **'prod.keys is required for this operation'**
  String get switchKeysRequired;

  /// No description provided for @keysFile.
  ///
  /// In en, this message translates to:
  /// **'prod.keys File'**
  String get keysFile;

  /// No description provided for @btnBrowseKeys.
  ///
  /// In en, this message translates to:
  /// **'Browse Keys'**
  String get btnBrowseKeys;

  /// No description provided for @compressionLevel.
  ///
  /// In en, this message translates to:
  /// **'Compression Level'**
  String get compressionLevel;

  /// No description provided for @statusCompressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing...'**
  String get statusCompressing;

  /// No description provided for @statusExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting...'**
  String get statusExtracting;

  /// No description provided for @statusMerging.
  ///
  /// In en, this message translates to:
  /// **'Merging...'**
  String get statusMerging;

  /// No description provided for @statusUnmerging.
  ///
  /// In en, this message translates to:
  /// **'Unmerging...'**
  String get statusUnmerging;

  /// No description provided for @statusDecompressing.
  ///
  /// In en, this message translates to:
  /// **'Decompressing...'**
  String get statusDecompressing;

  /// No description provided for @unmergeSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Wrote {count} NSP files to {dir}'**
  String unmergeSavedMessage(int count, String dir);

  /// No description provided for @unmergeMissingNcaWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} title(s) reference NCAs missing from the source NSP'**
  String unmergeMissingNcaWarning(int count);

  /// No description provided for @patchCompatibilityChecking.
  ///
  /// In en, this message translates to:
  /// **'Verifying ROM compatibility...'**
  String get patchCompatibilityChecking;

  /// No description provided for @patchCompatibilityCompatible.
  ///
  /// In en, this message translates to:
  /// **'Patch is compatible with the selected ROM'**
  String get patchCompatibilityCompatible;

  /// No description provided for @patchCompatibilityIncompatible.
  ///
  /// In en, this message translates to:
  /// **'Warning: ROM checksum does not match. This patch may be incompatible.'**
  String get patchCompatibilityIncompatible;

  /// No description provided for @patchCompatibilityUnverifiable.
  ///
  /// In en, this message translates to:
  /// **'This patch format does not support pre-verification'**
  String get patchCompatibilityUnverifiable;

  /// No description provided for @btnShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get btnShare;

  /// No description provided for @savedToFile.
  ///
  /// In en, this message translates to:
  /// **'Saved: {name}'**
  String savedToFile(String name);

  /// No description provided for @alreadyDecryptedMessage.
  ///
  /// In en, this message translates to:
  /// **'Already decrypted — no new file created'**
  String get alreadyDecryptedMessage;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove temporary and cached files'**
  String get clearCacheSubtitle;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @btnShowInFolder.
  ///
  /// In en, this message translates to:
  /// **'Show in folder'**
  String get btnShowInFolder;

  /// No description provided for @statusCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get statusCancelling;

  /// No description provided for @errInvalidFileType.
  ///
  /// In en, this message translates to:
  /// **'Invalid file type for the selected action'**
  String get errInvalidFileType;

  /// No description provided for @keysRequired3ds.
  ///
  /// In en, this message translates to:
  /// **'3dskeys.txt is required for this operation'**
  String get keysRequired3ds;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied {label} to clipboard'**
  String copiedToClipboard(String label);

  /// No description provided for @chdCodecsTitle.
  ///
  /// In en, this message translates to:
  /// **'Compression codecs'**
  String get chdCodecsTitle;

  /// No description provided for @chdCodecsHelper.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated: cdlz, cdzl, cdfl, cdzs, none'**
  String get chdCodecsHelper;

  /// No description provided for @chdHunkTitle.
  ///
  /// In en, this message translates to:
  /// **'Hunk size (bytes)'**
  String get chdHunkTitle;

  /// No description provided for @chdHunkHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for default'**
  String get chdHunkHelper;

  /// No description provided for @tabArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get tabArchive;

  /// No description provided for @archiveFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get archiveFormat;

  /// No description provided for @archiveCompressHint.
  ///
  /// In en, this message translates to:
  /// **'Drop any file here to compress'**
  String get archiveCompressHint;

  /// No description provided for @archiveDecompressHint.
  ///
  /// In en, this message translates to:
  /// **'Drop a .zip / .gz / .zst file here'**
  String get archiveDecompressHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'fr', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
