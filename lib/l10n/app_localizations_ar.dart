// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Final ROM';

  @override
  String get tabSingleFile => 'ملف واحد';

  @override
  String get tabThreeDs => '3DS';

  @override
  String get tabBatchMode => 'وضع الدُفعات';

  @override
  String get tabPatcher => 'الترقيع';

  @override
  String get tabHasher => 'التجزئة';

  @override
  String get btnDecrypt => 'فك التشفير';

  @override
  String get btnEncrypt => 'تشفير';

  @override
  String get btnCancel => 'إلغاء';

  @override
  String get btnClearQueue => 'مسح';

  @override
  String get btnBrowse => 'استعراض';

  @override
  String get btnBrowseFolder => 'مجلد';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get trimPadding => 'اقتطاع الحشو الزائد (فك التشفير)';

  @override
  String get trimPaddingDesc =>
      'يزيل حشو 0xFF الفارغ من نهاية الملف لتوفير المساحة.';

  @override
  String get outputHandling => 'معالجة المُخرَج';

  @override
  String get outputHandlingNewFile => 'إنشاء ملف جديد';

  @override
  String get outputHandlingOverwrite => 'الكتابة فوق الأصل (مُتلِف)';

  @override
  String get outputLocation => 'موقع المُخرَج';

  @override
  String get outputLocationNextToSource => 'بجوار الملف المصدر';

  @override
  String get outputLocationCustom => 'مجلد مخصص';

  @override
  String get outputLocationAppDocs => 'مجلد الجهاز (تخزين التطبيق)';

  @override
  String get conflictBehavior => 'إذا كان المُخرَج موجودًا';

  @override
  String get conflictAsk => 'اسأل';

  @override
  String get conflictOverwrite => 'الكتابة فوقه';

  @override
  String get conflictRename => 'إعادة تسمية تلقائية';

  @override
  String get parallelism => 'التوازي';

  @override
  String get parallelismDesc => 'عدد الملفات المعالَجة دفعة واحدة';

  @override
  String get themeMode => 'المظهر';

  @override
  String get themeSystem => 'افتراضي النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get dynamicColor => 'استخدام ألوان Material You الديناميكية';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'افتراضي النظام';

  @override
  String get statusIdle => 'خامل';

  @override
  String get statusDone => 'تم';

  @override
  String get statusError => 'خطأ';

  @override
  String get statusSaving => 'جارٍ الحفظ...';

  @override
  String statusFileSelected(String size) {
    return '$size ميبي بايت';
  }

  @override
  String trimMessage(String saved) {
    return 'تم اقتطاع $saved بايت من الحشو';
  }

  @override
  String batchSummary(int success, int failed, String time) {
    return 'نجح $success، فشل $failed (خلال $time ثانية)';
  }

  @override
  String batchProgress(int current, int total) {
    return 'تمت معالجة $current من $total';
  }

  @override
  String get errNoFileSelected => 'لم يتم تحديد ملف';

  @override
  String get errOutputFolderNotSelected => 'لم يتم تحديد مجلد المُخرَج';

  @override
  String get confirmOverwriteTitle => 'الكتابة فوق الأصل؟';

  @override
  String get confirmOverwriteContent =>
      'سيؤدي هذا إلى الكتابة فوق ملف ROM الأصلي بشكل مُتلِف. هل أنت متأكد أنك تريد المتابعة؟';

  @override
  String get btnYes => 'نعم';

  @override
  String get btnNo => 'لا';

  @override
  String get errInvalidRom => 'ملف 3DS ROM غير صالح';

  @override
  String get fileConflictTitle => 'الملف موجود بالفعل';

  @override
  String fileConflictContent(String filename) {
    return 'الملف $filename موجود بالفعل. ماذا تريد أن تفعل؟';
  }

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionOverwrite => 'الكتابة فوقه';

  @override
  String get actionRename => 'إعادة تسمية';

  @override
  String queueFileProgress(int current, int total) {
    return 'الملف $current من $total';
  }

  @override
  String queueDoneSummary(int ok, int total) {
    return 'اكتمل $ok من $total';
  }

  @override
  String queueFailuresSummary(int failed, int total) {
    return 'فشل $failed من $total';
  }

  @override
  String get aboutTitle => 'حول';

  @override
  String get aboutContent =>
      'يعمل هذا التطبيق دون اتصال تمامًا ولا يجمع أي بيانات شخصية.';

  @override
  String get dragDropHintSingle => 'أفلِت ملف 3DS ROM هنا';

  @override
  String get dragDropHintBatch => 'أفلِت ملفات 3DS ROM هنا';

  @override
  String get dragDropHintPatch => 'أفلِت ملف ROM أو رقعة هنا';

  @override
  String get dragDropHintHash => 'أفلِت ملفًا هنا لحساب التجزئة';

  @override
  String get dragDropOnly3ds => 'ملفات .3ds فقط مدعومة';

  @override
  String get dragDropSubtext => 'حرّر زر الفأرة للإفلات';

  @override
  String get romFile => 'ملف ROM الأساسي';

  @override
  String get patchFile =>
      'ملف الرقعة (.ips، .ups، .bps، .ppf، .aps، .ebp، .dps، .xdelta)';

  @override
  String get btnBrowseRom => 'استعراض ROM';

  @override
  String get btnBrowsePatch => 'استعراض الرقعة';

  @override
  String get btnPatch => 'تطبيق الرقعة';

  @override
  String get errNoPatchSelected => 'لم يتم تحديد رقعة';

  @override
  String get statusPatching => 'جارٍ تطبيق الرقعة...';

  @override
  String get fileToHash => 'الملف المراد تجزئته';

  @override
  String get statusHashing => 'جارٍ حساب قيم التجزئة...';

  @override
  String get ignoreChecksum => 'تجاهل المجموع الاختباري';

  @override
  String get ignoreChecksumSubtitle => 'تخطّي التحقق من ROM والرقعة';

  @override
  String get errUnsupportedPatch => 'صيغة رقعة غير مدعومة';

  @override
  String patchReportFormat(String format) {
    return 'الصيغة: $format';
  }

  @override
  String get patchReportNoChecksums =>
      'لا تحتوي هذه الصيغة على مجاميع اختبارية مضمّنة للتحقق.';

  @override
  String get checkOutcomePassed => 'ناجح';

  @override
  String get checkOutcomeSkipped => 'تم تخطّيه';

  @override
  String get tabChd => 'CHD';

  @override
  String get tabSwitch => 'Switch';

  @override
  String get chdCreate => 'إنشاء CHD';

  @override
  String get chdExtract => 'استخراج CHD';

  @override
  String get btnCreate => 'إنشاء';

  @override
  String get btnExtract => 'استخراج';

  @override
  String get btnMerge => 'دمج';

  @override
  String get btnUnmerge => 'إلغاء الدمج';

  @override
  String get btnCompress => 'ضغط';

  @override
  String get btnDecompress => 'فك الضغط';

  @override
  String get chdCreateHint => 'أفلِت ملف .cue أو .bin هنا';

  @override
  String get chdExtractHint => 'أفلِت ملف .chd هنا';

  @override
  String get chdDiscType => 'نوع القرص';

  @override
  String get chdDiscTypeCd => 'CD';

  @override
  String get chdDiscTypeDvd => 'DVD';

  @override
  String get switchMergeTab => 'دمج';

  @override
  String get switchSplitTab => 'إلغاء دمج';

  @override
  String get switchCompressTab => 'ضغط';

  @override
  String get switchDecompressTab => 'فك ضغط';

  @override
  String get switchMergeHint =>
      'أفلِت ملفات .nsp / .xci الأساسية والتحديثية هنا';

  @override
  String get switchUnmergeHint => 'أفلِت ملف .nsp مدموجًا هنا';

  @override
  String get switchCompressHint => 'أفلِت ملف .nsp هنا';

  @override
  String get switchDecompressHint => 'أفلِت ملف .nsz هنا';

  @override
  String get switchKeysRequired => 'ملف prod.keys مطلوب للضغط';

  @override
  String get keysFile => 'ملف prod.keys';

  @override
  String get btnBrowseKeys => 'استعراض المفاتيح';

  @override
  String get compressionLevel => 'مستوى الضغط';

  @override
  String get statusCompressing => 'جارٍ الضغط...';

  @override
  String get statusExtracting => 'جارٍ الاستخراج...';

  @override
  String get statusMerging => 'جارٍ الدمج...';

  @override
  String get statusUnmerging => 'جارٍ إلغاء الدمج...';

  @override
  String get statusDecompressing => 'جارٍ فك الضغط...';

  @override
  String unmergeSavedMessage(int count, String dir) {
    return 'تمت كتابة $count ملف NSP إلى $dir';
  }

  @override
  String unmergeMissingNcaWarning(int count) {
    return '$count عنوان يشير إلى ملفات NCA مفقودة من ملف NSP المصدر';
  }

  @override
  String get patchCompatibilityChecking => 'جارٍ التحقق من توافق ROM...';

  @override
  String get patchCompatibilityCompatible => 'الرقعة متوافقة مع ملف ROM المحدد';

  @override
  String get patchCompatibilityIncompatible =>
      'تحذير: المجموع الاختباري لـ ROM غير مطابق. قد تكون هذه الرقعة غير متوافقة.';

  @override
  String get patchCompatibilityUnverifiable =>
      'لا تدعم صيغة الرقعة هذه التحقق المسبق';

  @override
  String get btnShare => 'مشاركة';

  @override
  String savedToFile(String name) {
    return 'تم الحفظ: $name';
  }

  @override
  String get alreadyDecryptedMessage =>
      'تم فك تشفيره مسبقًا — لم يُنشأ ملف جديد';

  @override
  String get clearCache => 'مسح ذاكرة التخزين المؤقت';

  @override
  String get clearCacheSubtitle => 'إزالة الملفات المؤقتة والمخزّنة';

  @override
  String get cacheCleared => 'تم مسح ذاكرة التخزين المؤقت';

  @override
  String get btnSave => 'حفظ';

  @override
  String get btnShowInFolder => 'إظهار في المجلد';

  @override
  String get statusCancelling => 'جارٍ الإلغاء…';

  @override
  String get errInvalidFileType => 'نوع ملف غير صالح للإجراء المحدد';

  @override
  String get keysRequired3ds => 'ملف 3dskeys.txt مطلوب لهذه العملية';

  @override
  String copiedToClipboard(String label) {
    return 'تم نسخ $label إلى الحافظة';
  }

  @override
  String get chdCodecsTitle => 'خوارزميات الضغط';

  @override
  String get chdCodecsHelper => 'مفصولة بفواصل: cdlz، cdzl، cdfl، cdzs، none';

  @override
  String get chdHunkTitle => 'حجم القطعة (بايت)';

  @override
  String get chdHunkHelper => 'اتركه فارغًا للقيمة الافتراضية';
}
