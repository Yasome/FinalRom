// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Final ROM';

  @override
  String get tabSingleFile => 'Archivo único';

  @override
  String get tabThreeDs => '3DS';

  @override
  String get tabBatchMode => 'Modo por lotes';

  @override
  String get tabPatcher => 'Parcheador';

  @override
  String get tabHasher => 'Hasher';

  @override
  String get btnDecrypt => 'Descifrar';

  @override
  String get btnEncrypt => 'Cifrar';

  @override
  String get btnCancel => 'Cancelar';

  @override
  String get btnClearQueue => 'Limpiar';

  @override
  String get btnBrowse => 'Examinar';

  @override
  String get btnBrowseFolder => 'Carpeta';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get trimPadding => 'Recortar relleno final (Descifrar)';

  @override
  String get trimPaddingDesc =>
      'Elimina el relleno 0xFF vacío del final del archivo para ahorrar espacio.';

  @override
  String get outputHandling => 'Gestión de salida';

  @override
  String get outputHandlingNewFile => 'Crear un archivo nuevo';

  @override
  String get outputHandlingOverwrite =>
      'Sobrescribir el original (Destructivo)';

  @override
  String get outputLocation => 'Ubicación de salida';

  @override
  String get outputLocationNextToSource => 'Junto al archivo de origen';

  @override
  String get outputLocationCustom => 'Carpeta personalizada';

  @override
  String get outputLocationAppDocs =>
      'Carpeta del dispositivo (almacenamiento de la app)';

  @override
  String get conflictBehavior => 'Si la salida ya existe';

  @override
  String get conflictAsk => 'Preguntar';

  @override
  String get conflictOverwrite => 'Sobrescribir';

  @override
  String get conflictRename => 'Renombrar automáticamente';

  @override
  String get parallelism => 'Paralelismo';

  @override
  String get parallelismDesc => 'Archivos procesados a la vez';

  @override
  String get themeMode => 'Apariencia';

  @override
  String get themeSystem => 'Predeterminado del sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get dynamicColor => 'Usar color dinámico de Material You';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get statusIdle => 'Inactivo';

  @override
  String get statusDone => 'Hecho';

  @override
  String get statusError => 'Error';

  @override
  String get statusSaving => 'Guardando...';

  @override
  String statusFileSelected(String size) {
    return '$size MiB';
  }

  @override
  String trimMessage(String saved) {
    return 'Se recortaron $saved bytes de relleno';
  }

  @override
  String batchSummary(int success, int failed, String time) {
    return '$success con éxito, $failed con error (en $time s)';
  }

  @override
  String batchProgress(int current, int total) {
    return 'Procesados $current de $total';
  }

  @override
  String get errNoFileSelected => 'Ningún archivo seleccionado';

  @override
  String get errOutputFolderNotSelected => 'Carpeta de salida no seleccionada';

  @override
  String get confirmOverwriteTitle => '¿Sobrescribir el original?';

  @override
  String get confirmOverwriteContent =>
      'Esto sobrescribirá de forma destructiva el archivo ROM original. ¿Seguro que quieres continuar?';

  @override
  String get btnYes => 'Sí';

  @override
  String get btnNo => 'No';

  @override
  String get errInvalidRom => 'ROM de 3DS no válida';

  @override
  String get fileConflictTitle => 'El archivo ya existe';

  @override
  String fileConflictContent(String filename) {
    return 'El archivo $filename ya existe. ¿Qué quieres hacer?';
  }

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionOverwrite => 'Sobrescribir';

  @override
  String get actionRename => 'Renombrar';

  @override
  String queueFileProgress(int current, int total) {
    return 'Archivo $current de $total';
  }

  @override
  String queueDoneSummary(int ok, int total) {
    return '$ok de $total completados';
  }

  @override
  String queueFailuresSummary(int failed, int total) {
    return '$failed de $total fallidos';
  }

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutContent =>
      'Esta aplicación funciona completamente sin conexión y no recopila datos personales.';

  @override
  String get dragDropHintSingle => 'Suelta aquí el archivo ROM .3ds';

  @override
  String get dragDropHintBatch => 'Suelta aquí los archivos ROM .3ds';

  @override
  String get dragDropHintRom => 'Suelta aquí el archivo ROM';

  @override
  String get dragDropHintPatch => 'Suelta aquí el archivo de parche';

  @override
  String get dragDropHintHash => 'Suelta aquí un archivo para calcular el hash';

  @override
  String get dragDropOnly3ds => 'Solo se admiten archivos .3ds';

  @override
  String get dragDropSubtext => 'Suelta el ratón para soltar el archivo';

  @override
  String get romFile => 'Archivo ROM base';

  @override
  String get patchFile =>
      'Archivo de parche (.ips, .ups, .bps, .ppf, .aps, .ebp, .dps, .xdelta)';

  @override
  String get btnBrowseRom => 'Examinar ROM';

  @override
  String get btnBrowsePatch => 'Examinar parche';

  @override
  String get btnPatch => 'Aplicar parche';

  @override
  String get errNoPatchSelected => 'Ningún parche seleccionado';

  @override
  String get statusPatching => 'Aplicando parche...';

  @override
  String get fileToHash => 'Archivo para calcular hash';

  @override
  String get statusHashing => 'Calculando hashes...';

  @override
  String get ignoreChecksum => 'Ignorar suma de verificación';

  @override
  String get ignoreChecksumSubtitle => 'Omitir la verificación de ROM y parche';

  @override
  String get errUnsupportedPatch => 'Formato de parche no admitido';

  @override
  String patchReportFormat(String format) {
    return 'Formato: $format';
  }

  @override
  String get patchReportNoChecksums =>
      'Este formato no tiene sumas de verificación integradas para comprobar.';

  @override
  String get checkOutcomePassed => 'Correcto';

  @override
  String get checkOutcomeSkipped => 'Omitido';

  @override
  String get tabChd => 'CHD';

  @override
  String get tabSwitch => 'Switch';

  @override
  String get chdCreate => 'Crear CHD';

  @override
  String get chdExtract => 'Extraer CHD';

  @override
  String get btnCreate => 'Crear';

  @override
  String get btnExtract => 'Extraer';

  @override
  String get btnMerge => 'Combinar';

  @override
  String get btnUnmerge => 'Separar';

  @override
  String get btnCompress => 'Comprimir';

  @override
  String get btnDecompress => 'Descomprimir';

  @override
  String get chdCreateHint => 'Suelta aquí un archivo .cue o .iso';

  @override
  String get chdExtractHint => 'Suelta aquí un archivo .chd';

  @override
  String get chdDiscType => 'Tipo de disco';

  @override
  String get chdDiscTypeCd => 'CD';

  @override
  String get chdDiscTypeDvd => 'DVD';

  @override
  String get chdBinNeedsCue =>
      'Un .bin es una pista sin procesar: añade su hoja .cue en su lugar.';

  @override
  String get switchMergeTab => 'Combinar';

  @override
  String get switchSplitTab => 'Separar';

  @override
  String get switchCompressTab => 'Comprimir';

  @override
  String get switchDecompressTab => 'Descomprimir';

  @override
  String get switchMergeHint =>
      'Suelta aquí los archivos base y de actualización .nsp / .xci';

  @override
  String get switchUnmergeHint => 'Suelta aquí un archivo .nsp combinado';

  @override
  String get switchCompressHint => 'Suelta aquí un archivo .nsp';

  @override
  String get switchDecompressHint => 'Suelta aquí un archivo .nsz';

  @override
  String get switchKeysRequired => 'Se requiere prod.keys para la compresión';

  @override
  String get keysFile => 'Archivo prod.keys';

  @override
  String get btnBrowseKeys => 'Examinar claves';

  @override
  String get compressionLevel => 'Nivel de compresión';

  @override
  String get statusCompressing => 'Comprimiendo...';

  @override
  String get statusExtracting => 'Extrayendo...';

  @override
  String get statusMerging => 'Combinando...';

  @override
  String get statusUnmerging => 'Separando...';

  @override
  String get statusDecompressing => 'Descomprimiendo...';

  @override
  String unmergeSavedMessage(int count, String dir) {
    return 'Se escribieron $count archivos NSP en $dir';
  }

  @override
  String unmergeMissingNcaWarning(int count) {
    return '$count título(s) hacen referencia a NCA que faltan en el NSP de origen';
  }

  @override
  String get patchCompatibilityChecking =>
      'Verificando la compatibilidad de la ROM...';

  @override
  String get patchCompatibilityCompatible =>
      'El parche es compatible con la ROM seleccionada';

  @override
  String get patchCompatibilityIncompatible =>
      'Advertencia: la suma de verificación de la ROM no coincide. Este parche podría ser incompatible.';

  @override
  String get patchCompatibilityUnverifiable =>
      'Este formato de parche no admite verificación previa';

  @override
  String get btnShare => 'Compartir';

  @override
  String savedToFile(String name) {
    return 'Guardado: $name';
  }

  @override
  String get alreadyDecryptedMessage =>
      'Ya estaba descifrado — no se creó ningún archivo nuevo';

  @override
  String get clearCache => 'Borrar caché';

  @override
  String get clearCacheSubtitle => 'Eliminar archivos temporales y en caché';

  @override
  String get cacheCleared => 'Caché borrada';

  @override
  String get btnSave => 'Guardar';

  @override
  String get btnShowInFolder => 'Mostrar en la carpeta';

  @override
  String get statusCancelling => 'Cancelando…';

  @override
  String get errInvalidFileType =>
      'Tipo de archivo no válido para la acción seleccionada';

  @override
  String get keysRequired3ds => 'Se requiere 3dskeys.txt para esta operación';

  @override
  String copiedToClipboard(String label) {
    return 'Se copió $label al portapapeles';
  }

  @override
  String get chdCodecsTitle => 'Códecs de compresión';

  @override
  String get chdCodecsHelper =>
      'Separados por comas: cdlz, cdzl, cdfl, cdzs, none';

  @override
  String get chdHunkTitle => 'Tamaño de hunk (bytes)';

  @override
  String get chdHunkHelper => 'Déjalo vacío para el valor predeterminado';

  @override
  String get tabArchive => 'Archivo';

  @override
  String get archiveFormat => 'Formato';

  @override
  String get archiveCompressHint =>
      'Suelta cualquier archivo aquí para comprimir';

  @override
  String get archiveDecompressHint =>
      'Suelta un archivo .zip / .gz / .zst aquí';
}
