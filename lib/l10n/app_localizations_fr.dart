// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Final ROM';

  @override
  String get tabSingleFile => 'Fichier unique';

  @override
  String get tabThreeDs => '3DS';

  @override
  String get tabBatchMode => 'Mode par lots';

  @override
  String get tabPatcher => 'Patcheur';

  @override
  String get tabHasher => 'Hachage';

  @override
  String get btnDecrypt => 'Déchiffrer';

  @override
  String get btnEncrypt => 'Chiffrer';

  @override
  String get btnCancel => 'Annuler';

  @override
  String get btnClearQueue => 'Effacer';

  @override
  String get btnBrowse => 'Parcourir';

  @override
  String get btnBrowseFolder => 'Dossier';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get trimPadding => 'Rogner le remplissage final (Déchiffrement)';

  @override
  String get trimPaddingDesc =>
      'Supprime le remplissage 0xFF vide à la fin du fichier pour gagner de l\'espace.';

  @override
  String get outputHandling => 'Gestion de la sortie';

  @override
  String get outputHandlingNewFile => 'Créer un nouveau fichier';

  @override
  String get outputHandlingOverwrite => 'Écraser l\'original (Destructif)';

  @override
  String get outputLocation => 'Emplacement de sortie';

  @override
  String get outputLocationNextToSource => 'À côté du fichier source';

  @override
  String get outputLocationCustom => 'Dossier personnalisé';

  @override
  String get outputLocationAppDocs =>
      'Dossier de l\'appareil (stockage de l\'app)';

  @override
  String get conflictBehavior => 'Si la sortie existe';

  @override
  String get conflictAsk => 'Demander';

  @override
  String get conflictOverwrite => 'Écraser';

  @override
  String get conflictRename => 'Renommer automatiquement';

  @override
  String get parallelism => 'Parallélisme';

  @override
  String get parallelismDesc => 'Fichiers traités simultanément';

  @override
  String get themeMode => 'Apparence';

  @override
  String get themeSystem => 'Paramètre du système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get dynamicColor => 'Utiliser les couleurs dynamiques Material You';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Paramètre du système';

  @override
  String get statusIdle => 'Inactif';

  @override
  String get statusDone => 'Terminé';

  @override
  String get statusError => 'Erreur';

  @override
  String get statusSaving => 'Enregistrement...';

  @override
  String statusFileSelected(String size) {
    return '$size Mio';
  }

  @override
  String trimMessage(String saved) {
    return '$saved octets de remplissage rognés';
  }

  @override
  String batchSummary(int success, int failed, String time) {
    return '$success réussi(s), $failed échoué(s) (en $time s)';
  }

  @override
  String batchProgress(int current, int total) {
    return '$current sur $total traités';
  }

  @override
  String get errNoFileSelected => 'Aucun fichier sélectionné';

  @override
  String get errOutputFolderNotSelected => 'Dossier de sortie non sélectionné';

  @override
  String get confirmOverwriteTitle => 'Écraser l\'original ?';

  @override
  String get confirmOverwriteContent =>
      'Cela écrasera de manière destructive le fichier ROM original. Voulez-vous vraiment continuer ?';

  @override
  String get btnYes => 'Oui';

  @override
  String get btnNo => 'Non';

  @override
  String get errInvalidRom => 'ROM 3DS non valide';

  @override
  String get fileConflictTitle => 'Le fichier existe déjà';

  @override
  String fileConflictContent(String filename) {
    return 'Le fichier $filename existe déjà. Que voulez-vous faire ?';
  }

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionOverwrite => 'Écraser';

  @override
  String get actionRename => 'Renommer';

  @override
  String queueFileProgress(int current, int total) {
    return 'Fichier $current sur $total';
  }

  @override
  String queueDoneSummary(int ok, int total) {
    return '$ok sur $total terminés';
  }

  @override
  String queueFailuresSummary(int failed, int total) {
    return '$failed sur $total en échec';
  }

  @override
  String get aboutTitle => 'À propos';

  @override
  String get aboutContent =>
      'Cette application fonctionne entièrement hors ligne et ne collecte aucune donnée personnelle.';

  @override
  String get dragDropHintSingle => 'Déposez ici le fichier ROM .3ds';

  @override
  String get dragDropHintBatch => 'Déposez ici les fichiers ROM .3ds';

  @override
  String get dragDropHintPatch => 'Déposez ici un fichier ROM ou de correctif';

  @override
  String get dragDropHintHash => 'Déposez ici un fichier à hacher';

  @override
  String get dragDropOnly3ds => 'Seuls les fichiers .3ds sont pris en charge';

  @override
  String get dragDropSubtext => 'Relâchez la souris pour déposer';

  @override
  String get romFile => 'Fichier ROM de base';

  @override
  String get patchFile =>
      'Fichier de correctif (.ips, .ups, .bps, .ppf, .aps, .ebp, .dps, .xdelta)';

  @override
  String get btnBrowseRom => 'Parcourir la ROM';

  @override
  String get btnBrowsePatch => 'Parcourir le correctif';

  @override
  String get btnPatch => 'Appliquer le correctif';

  @override
  String get errNoPatchSelected => 'Aucun correctif sélectionné';

  @override
  String get statusPatching => 'Application du correctif...';

  @override
  String get fileToHash => 'Fichier à hacher';

  @override
  String get statusHashing => 'Calcul des hachages...';

  @override
  String get ignoreChecksum => 'Ignorer la somme de contrôle';

  @override
  String get ignoreChecksumSubtitle =>
      'Ignorer la vérification de la ROM et du correctif';

  @override
  String get errUnsupportedPatch => 'Format de correctif non pris en charge';

  @override
  String patchReportFormat(String format) {
    return 'Format : $format';
  }

  @override
  String get patchReportNoChecksums =>
      'Ce format ne contient pas de sommes de contrôle intégrées à vérifier.';

  @override
  String get checkOutcomePassed => 'Réussi';

  @override
  String get checkOutcomeSkipped => 'Ignoré';

  @override
  String get tabChd => 'CHD';

  @override
  String get tabSwitch => 'Switch';

  @override
  String get chdCreate => 'Créer un CHD';

  @override
  String get chdExtract => 'Extraire le CHD';

  @override
  String get btnCreate => 'Créer';

  @override
  String get btnExtract => 'Extraire';

  @override
  String get btnMerge => 'Fusionner';

  @override
  String get btnUnmerge => 'Défusionner';

  @override
  String get btnCompress => 'Compresser';

  @override
  String get btnDecompress => 'Décompresser';

  @override
  String get chdCreateHint => 'Déposez ici un fichier .cue ou .bin';

  @override
  String get chdExtractHint => 'Déposez ici un fichier .chd';

  @override
  String get chdDiscType => 'Disc type';

  @override
  String get chdDiscTypeCd => 'CD';

  @override
  String get chdDiscTypeDvd => 'DVD';

  @override
  String get switchMergeTab => 'Fusionner';

  @override
  String get switchSplitTab => 'Défusionner';

  @override
  String get switchCompressTab => 'Compresser';

  @override
  String get switchDecompressTab => 'Décompresser';

  @override
  String get switchMergeHint =>
      'Déposez ici les fichiers de base et de mise à jour .nsp / .xci';

  @override
  String get switchUnmergeHint => 'Déposez ici un fichier .nsp fusionné';

  @override
  String get switchCompressHint => 'Déposez ici un fichier .nsp';

  @override
  String get switchDecompressHint => 'Déposez ici un fichier .nsz';

  @override
  String get switchKeysRequired => 'prod.keys est requis pour la compression';

  @override
  String get keysFile => 'Fichier prod.keys';

  @override
  String get btnBrowseKeys => 'Parcourir les clés';

  @override
  String get compressionLevel => 'Niveau de compression';

  @override
  String get statusCompressing => 'Compression...';

  @override
  String get statusExtracting => 'Extraction...';

  @override
  String get statusMerging => 'Fusion...';

  @override
  String get statusUnmerging => 'Défusion...';

  @override
  String get statusDecompressing => 'Décompression...';

  @override
  String unmergeSavedMessage(int count, String dir) {
    return '$count fichiers NSP écrits dans $dir';
  }

  @override
  String unmergeMissingNcaWarning(int count) {
    return '$count titre(s) référencent des NCA absents du NSP source';
  }

  @override
  String get patchCompatibilityChecking =>
      'Vérification de la compatibilité de la ROM...';

  @override
  String get patchCompatibilityCompatible =>
      'Le correctif est compatible avec la ROM sélectionnée';

  @override
  String get patchCompatibilityIncompatible =>
      'Avertissement : la somme de contrôle de la ROM ne correspond pas. Ce correctif peut être incompatible.';

  @override
  String get patchCompatibilityUnverifiable =>
      'Ce format de correctif ne prend pas en charge la vérification préalable';

  @override
  String get btnShare => 'Partager';

  @override
  String savedToFile(String name) {
    return 'Enregistré : $name';
  }

  @override
  String get alreadyDecryptedMessage =>
      'Déjà déchiffré — aucun nouveau fichier créé';

  @override
  String get clearCache => 'Vider le cache';

  @override
  String get clearCacheSubtitle =>
      'Supprimer les fichiers temporaires et en cache';

  @override
  String get cacheCleared => 'Cache vidé';

  @override
  String get btnSave => 'Enregistrer';

  @override
  String get btnShowInFolder => 'Afficher dans le dossier';

  @override
  String get statusCancelling => 'Annulation…';

  @override
  String get errInvalidFileType =>
      'Type de fichier non valide pour l\'action sélectionnée';

  @override
  String get keysRequired3ds => '3dskeys.txt est requis pour cette opération';

  @override
  String copiedToClipboard(String label) {
    return '$label copié dans le presse-papiers';
  }

  @override
  String get chdCodecsTitle => 'Codecs de compression';

  @override
  String get chdCodecsHelper =>
      'Séparés par des virgules : cdlz, cdzl, cdfl, cdzs, none';

  @override
  String get chdHunkTitle => 'Taille de hunk (octets)';

  @override
  String get chdHunkHelper => 'Laisser vide pour la valeur par défaut';
}
