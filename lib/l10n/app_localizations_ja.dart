// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Final ROM';

  @override
  String get tabSingleFile => '単一ファイル';

  @override
  String get tabThreeDs => '3DS';

  @override
  String get tabBatchMode => 'バッチモード';

  @override
  String get tabPatcher => 'パッチャー';

  @override
  String get tabHasher => 'ハッシュ';

  @override
  String get btnDecrypt => '復号';

  @override
  String get btnEncrypt => '暗号化';

  @override
  String get btnCancel => 'キャンセル';

  @override
  String get btnClearQueue => 'クリア';

  @override
  String get btnBrowse => '参照';

  @override
  String get btnBrowseFolder => 'フォルダ';

  @override
  String get settingsTitle => '設定';

  @override
  String get trimPadding => '末尾のパディングを除去（復号）';

  @override
  String get trimPaddingDesc => 'ファイル末尾の空の0xFFパディングを削除して容量を節約します。';

  @override
  String get outputHandling => '出力の扱い';

  @override
  String get outputHandlingNewFile => '新しいファイルを作成';

  @override
  String get outputHandlingOverwrite => '元のファイルを上書き（破壊的）';

  @override
  String get outputLocation => '出力先';

  @override
  String get outputLocationNextToSource => '元ファイルの隣';

  @override
  String get outputLocationCustom => 'カスタムフォルダ';

  @override
  String get outputLocationAppDocs => 'デバイスフォルダ（アプリ保存領域）';

  @override
  String get conflictBehavior => '出力が存在する場合';

  @override
  String get conflictAsk => '確認する';

  @override
  String get conflictOverwrite => '上書き';

  @override
  String get conflictRename => '自動リネーム';

  @override
  String get parallelism => '並列処理数';

  @override
  String get parallelismDesc => '同時に処理するファイル数';

  @override
  String get themeMode => '外観';

  @override
  String get themeSystem => 'システム既定';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get dynamicColor => 'Material You のダイナミックカラーを使用';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システム既定';

  @override
  String get statusIdle => '待機中';

  @override
  String get statusDone => '完了';

  @override
  String get statusError => 'エラー';

  @override
  String get statusSaving => '保存中...';

  @override
  String statusFileSelected(String size) {
    return '$size MiB';
  }

  @override
  String trimMessage(String saved) {
    return '$saved バイトのパディングを除去しました';
  }

  @override
  String batchSummary(int success, int failed, String time) {
    return '成功 $success 件、失敗 $failed 件（$time 秒）';
  }

  @override
  String batchProgress(int current, int total) {
    return '$total 件中 $current 件を処理';
  }

  @override
  String get errNoFileSelected => 'ファイルが選択されていません';

  @override
  String get errOutputFolderNotSelected => '出力フォルダが選択されていません';

  @override
  String get confirmOverwriteTitle => '元のファイルを上書きしますか？';

  @override
  String get confirmOverwriteContent => '元の ROM ファイルを破壊的に上書きします。続行してもよろしいですか？';

  @override
  String get btnYes => 'はい';

  @override
  String get btnNo => 'いいえ';

  @override
  String get errInvalidRom => '無効な 3DS ROM';

  @override
  String get fileConflictTitle => 'ファイルは既に存在します';

  @override
  String fileConflictContent(String filename) {
    return 'ファイル $filename は既に存在します。どうしますか？';
  }

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionOverwrite => '上書き';

  @override
  String get actionRename => 'リネーム';

  @override
  String queueFileProgress(int current, int total) {
    return 'ファイル $current / $total';
  }

  @override
  String queueDoneSummary(int ok, int total) {
    return '$total 件中 $ok 件完了';
  }

  @override
  String queueFailuresSummary(int failed, int total) {
    return '$total 件中 $failed 件失敗';
  }

  @override
  String get aboutTitle => '情報';

  @override
  String get aboutContent => 'このアプリは完全にオフラインで動作し、個人データを一切収集しません。';

  @override
  String get dragDropHintSingle => '.3ds ROM ファイルをここにドロップ';

  @override
  String get dragDropHintBatch => '.3ds ROM ファイルをここにドロップ';

  @override
  String get dragDropHintRom => 'ROM ファイルをここにドロップ';

  @override
  String get dragDropHintPatch => 'パッチファイルをここにドロップ';

  @override
  String get dragDropHintHash => 'ハッシュを計算するファイルをここにドロップ';

  @override
  String get dragDropOnly3ds => '.3ds ファイルのみ対応しています';

  @override
  String get dragDropSubtext => 'マウスを離してドロップ';

  @override
  String get romFile => 'ベース ROM ファイル';

  @override
  String get patchFile =>
      'パッチファイル (.ips, .ups, .bps, .ppf, .aps, .ebp, .dps, .xdelta)';

  @override
  String get btnBrowseRom => 'ROM を参照';

  @override
  String get btnBrowsePatch => 'パッチを参照';

  @override
  String get btnPatch => 'パッチを適用';

  @override
  String get errNoPatchSelected => 'パッチが選択されていません';

  @override
  String get statusPatching => 'パッチを適用中...';

  @override
  String get fileToHash => 'ハッシュ対象ファイル';

  @override
  String get statusHashing => 'ハッシュを計算中...';

  @override
  String get ignoreChecksum => 'チェックサムを無視';

  @override
  String get ignoreChecksumSubtitle => 'ROM とパッチの検証をスキップ';

  @override
  String get errUnsupportedPatch => '対応していないパッチ形式';

  @override
  String patchReportFormat(String format) {
    return '形式: $format';
  }

  @override
  String get patchReportNoChecksums => 'この形式には検証用の埋め込みチェックサムがありません。';

  @override
  String get checkOutcomePassed => '合格';

  @override
  String get checkOutcomeSkipped => 'スキップ';

  @override
  String get tabChd => 'CHD';

  @override
  String get tabSwitch => 'Switch';

  @override
  String get chdCreate => 'CHD を作成';

  @override
  String get chdExtract => 'CHD を展開';

  @override
  String get btnCreate => '作成';

  @override
  String get btnExtract => '展開';

  @override
  String get btnMerge => '結合';

  @override
  String get btnUnmerge => '分割';

  @override
  String get btnCompress => '圧縮';

  @override
  String get btnDecompress => '展開';

  @override
  String get chdCreateHint => '.cue または .bin ファイルをここにドロップ';

  @override
  String get chdExtractHint => '.chd ファイルをここにドロップ';

  @override
  String get chdDiscType => 'ディスクの種類';

  @override
  String get chdDiscTypeCd => 'CD';

  @override
  String get chdDiscTypeDvd => 'DVD';

  @override
  String get switchMergeTab => '結合';

  @override
  String get switchSplitTab => '分割';

  @override
  String get switchCompressTab => 'NSZ に圧縮';

  @override
  String get switchDecompressTab => '展開';

  @override
  String get switchMergeHint => 'ベースとアップデートの .nsp / .xci ファイルをここにドロップ';

  @override
  String get switchUnmergeHint => '結合済みの .nsp ファイルをここにドロップ';

  @override
  String get switchCompressHint => '.nsp ファイルをここにドロップ';

  @override
  String get switchDecompressHint => '.nsz ファイルをここにドロップ';

  @override
  String get switchKeysRequired => '圧縮には prod.keys が必要です';

  @override
  String get keysFile => 'prod.keys ファイル';

  @override
  String get btnBrowseKeys => 'キーを参照';

  @override
  String get compressionLevel => '圧縮レベル';

  @override
  String get statusCompressing => '圧縮中...';

  @override
  String get statusExtracting => '展開中...';

  @override
  String get statusMerging => '結合中...';

  @override
  String get statusUnmerging => '分割中...';

  @override
  String get statusDecompressing => '展開中...';

  @override
  String unmergeSavedMessage(int count, String dir) {
    return '$count 個の NSP ファイルを $dir に書き出しました';
  }

  @override
  String unmergeMissingNcaWarning(int count) {
    return '$count 個のタイトルが、ソース NSP に存在しない NCA を参照しています';
  }

  @override
  String get patchCompatibilityChecking => 'ROM の互換性を確認中...';

  @override
  String get patchCompatibilityCompatible => 'パッチは選択した ROM と互換性があります';

  @override
  String get patchCompatibilityIncompatible =>
      '警告: ROM のチェックサムが一致しません。このパッチは互換性がない可能性があります。';

  @override
  String get patchCompatibilityUnverifiable => 'このパッチ形式は事前検証に対応していません';

  @override
  String get btnShare => '共有';

  @override
  String savedToFile(String name) {
    return '保存しました: $name';
  }

  @override
  String get alreadyDecryptedMessage => '既に復号済み — 新しいファイルは作成されませんでした';

  @override
  String get clearCache => 'キャッシュを消去';

  @override
  String get clearCacheSubtitle => '一時ファイルとキャッシュを削除';

  @override
  String get cacheCleared => 'キャッシュを消去しました';

  @override
  String get btnSave => '保存';

  @override
  String get btnShowInFolder => 'フォルダで表示';

  @override
  String get statusCancelling => 'キャンセル中…';

  @override
  String get errInvalidFileType => '選択した操作に対して無効なファイル形式です';

  @override
  String get keysRequired3ds => 'この操作には 3dskeys.txt が必要です';

  @override
  String copiedToClipboard(String label) {
    return '$label をクリップボードにコピーしました';
  }

  @override
  String get chdCodecsTitle => '圧縮コーデック';

  @override
  String get chdCodecsHelper => 'カンマ区切り: cdlz, cdzl, cdfl, cdzs, none';

  @override
  String get chdHunkTitle => 'ハンクサイズ（バイト）';

  @override
  String get chdHunkHelper => 'デフォルトの場合は空欄';
}
