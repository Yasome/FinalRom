import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:final_rom/l10n/app_localizations.dart';

import '../services/file_service.dart';
import '../services/archive_service.dart';
import '../services/archive_worker.dart';
import '../blocs/archive_bloc.dart';
import '../blocs/queue_progress.dart';
import '../settings/settings_cubit.dart';
import '../settings/app_settings.dart';
import 'home_screen.dart';
import 'android_file_picker.dart';
import 'app_spacing.dart';
import 'widgets/dialogs.dart';

class ArchiveTab extends StatefulWidget {
  const ArchiveTab({super.key});

  @override
  State<ArchiveTab> createState() => _ArchiveTabState();
}

class _ArchiveTabState extends State<ArchiveTab> {
  ArchiveAction _action = ArchiveAction.compress;

  /// Output format used when compressing. 7-Zip is intentionally absent until
  /// the native plugin lands; decompression infers the format from the input.
  ArchiveFormat _format = ArchiveFormat.zip;

  static const List<ArchiveFormat> _compressFormats = [
    ArchiveFormat.zip,
    ArchiveFormat.sevenZip,
    ArchiveFormat.gzip,
    ArchiveFormat.zstd,
  ];

  // Archives this tab can decompress, handled by the native libarchive backend.
  static const List<String> _decompressExtensions = ['zip', '7z', 'gz', 'zst'];

  List<String> _selectedFiles = [];

  bool _isValidForAction(String path) {
    if (_action == ArchiveAction.compress) return true;
    return ArchiveService.formatForArchive(path) != null;
  }

  void _addFiles(Iterable<String> paths) {
    final valid = paths.where(_isValidForAction);
    if (valid.isEmpty) return;
    setState(() {
      _selectedFiles.addAll(valid);
      _selectedFiles = _selectedFiles.toSet().toList();
    });
  }

  String _formatLabel(ArchiveFormat format) {
    switch (format) {
      case ArchiveFormat.zip:
        return 'ZIP (.zip)';
      case ArchiveFormat.gzip:
        return 'Gzip (.gz)';
      case ArchiveFormat.zstd:
        return 'Zstandard (.zst)';
      case ArchiveFormat.sevenZip:
        return '7-Zip (.7z)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DragDropTarget(
      hintText: _action == ArchiveAction.compress
          ? loc.archiveCompressHint
          : loc.archiveDecompressHint,
      onFilesDropped: (paths) {
        final hadValid = paths.any(_isValidForAction);
        _addFiles(paths);
        if (!hadValid) showErrorSnackBar(context, loc.errInvalidFileType);
      },
      child: BlocConsumer<ArchiveBloc, ArchiveState>(
        listener: (context, state) {
          if (state is ArchiveBatchDone) {
            _onBatchDone(context, loc, state);
          }
        },
        builder: (context, state) {
          final isRunning = state is ArchiveRunning || state is ArchiveProgress;
          final double? progressValue =
              state is ArchiveProgress ? state.fraction : null;
          final QueuePosition? position =
              state is ArchiveProgress ? state.position : null;
          final statusLabel = _action == ArchiveAction.compress
              ? loc.statusCompressing
              : loc.statusDecompressing;
          return Padding(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ArchiveAction>(
                  segments: [
                    ButtonSegment(
                      value: ArchiveAction.compress,
                      label: Text(loc.btnCompress),
                      icon: const Icon(Icons.compress),
                    ),
                    ButtonSegment(
                      value: ArchiveAction.decompress,
                      label: Text(loc.btnDecompress),
                      icon: const Icon(Icons.unarchive),
                    ),
                  ],
                  selected: {_action},
                  onSelectionChanged: isRunning
                      ? null
                      : (newSelection) {
                          setState(() {
                            _action = newSelection.first;
                            _selectedFiles = [];
                          });
                        },
                ),
                if (_action == ArchiveAction.compress) ...[
                  AppSpacing.gapLg,
                  Row(
                    children: [
                      Text(loc.archiveFormat),
                      AppSpacing.gapMd,
                      Expanded(
                        child: DropdownButton<ArchiveFormat>(
                          isExpanded: true,
                          value: _format,
                          onChanged: isRunning
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _format = value);
                                  }
                                },
                          items: [
                            for (final format in _compressFormats)
                              DropdownMenuItem(
                                value: format,
                                child: Text(_formatLabel(format)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                AppSpacing.gapLg,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(loc.btnBrowse),
                      onPressed: isRunning ? null : () => _browse(context),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.clear_all),
                      label: Text(loc.btnClearQueue),
                      onPressed: isRunning || _selectedFiles.isEmpty
                          ? null
                          : () => setState(() => _selectedFiles = []),
                    ),
                  ],
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Card(
                    child: _selectedFiles.isEmpty
                        ? Center(child: Text(loc.errNoFileSelected))
                        : ListView.builder(
                            itemCount: _selectedFiles.length,
                            itemBuilder: (context, index) {
                              final path = _selectedFiles[index];
                              return ListTile(
                                key: ValueKey(path),
                                leading: const Icon(Icons.file_present),
                                title: Text(p.basename(path)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: isRunning
                                      ? null
                                      : () => setState(
                                          () => _selectedFiles.removeAt(index)),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                AppSpacing.gapMd,
                if (isRunning) ...[
                  LinearProgressIndicator(value: progressValue),
                  AppSpacing.gapSm,
                  Text(
                    _runningLabel(loc, statusLabel, progressValue, position),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  AppSpacing.gapMd,
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (isRunning)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: () {
                          context.read<ArchiveBloc>().add(CancelArchive());
                          showInfoSnackBar(context, loc.statusCancelling);
                        },
                        child: Text(loc.btnCancel),
                      )
                    else
                      FilledButton(
                        onPressed: _selectedFiles.isEmpty
                            ? null
                            : () => _runAction(context),
                        child: Text(_action == ArchiveAction.compress
                            ? loc.btnCompress
                            : loc.btnDecompress),
                      ),
                  ],
                ),
                AppSpacing.gapMd,
              ],
            ),
          );
        },
      ),
    );
  }

  String _runningLabel(
    AppLocalizations loc,
    String statusLabel,
    double? progressValue,
    QueuePosition? position,
  ) {
    final percent = progressValue != null
        ? ' ${(progressValue * 100).toStringAsFixed(0)}%'
        : '';
    if (position != null && position.isBatch) {
      return '${loc.queueFileProgress(position.currentIndex, position.total)} · $statusLabel$percent';
    }
    return '$statusLabel$percent';
  }

  void _onBatchDone(
      BuildContext context, AppLocalizations loc, ArchiveBatchDone state) {
    final total = state.results.length;
    if (total == 0) return;
    final timeStr =
        '${(state.duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
    if (state.results.hasFailures) {
      final firstError = state.results.firstWhere((r) => !r.success).error;
      showErrorSnackBar(
        context,
        '${loc.queueFailuresSummary(state.results.failureCount, total)}'
        '${firstError != null ? ': $firstError' : ''}',
      );
    }
    final ok = state.results.successCount;
    if (ok > 0) {
      if (total == 1) {
        showSavedSnackBar(context, state.results.first.outputPath ?? '',
            trailing: timeStr);
      } else {
        showInfoSnackBar(context, '${loc.queueDoneSummary(ok, total)} ($timeStr)');
      }
    }
  }

  Future<void> _browse(BuildContext context) async {
    List<String> files = [];
    if (Platform.isAndroid) {
      final allowed =
          _action == ArchiveAction.compress ? <String>[] : _decompressExtensions;
      final picked =
          await AndroidFilePicker.pickFiles(context, allowedExtensions: allowed);
      if (picked != null) files.addAll(picked);
    } else if (_action == ArchiveAction.compress) {
      files = await FileService.pickAnyFiles();
    } else {
      files = await FileService.pickFiles(
          allowMultiple: true, allowedExtensions: _decompressExtensions);
    }
    _addFiles(files);
  }

  Future<void> _runAction(BuildContext context) async {
    if (_selectedFiles.isEmpty) return;
    final settings = context.read<SettingsCubit>().state;

    Future<String> outputDirFor(String inputFile) async {
      if (settings.outputLocation == OutputLocation.customDir) {
        return settings.customOutputDir ?? p.dirname(inputFile);
      } else if (settings.outputLocation == OutputLocation.appDocuments) {
        return FileService.getMobileOutputDirectory();
      }
      return p.dirname(inputFile);
    }

    final jobs = <ArchiveJob>[];
    final existingOutputs = <String>[];
    for (final file in _selectedFiles) {
      final dir = await outputDirFor(file);
      final String outputPath;
      final ArchiveFormat format;
      if (_action == ArchiveAction.compress) {
        format = _format;
        final ext = ArchiveService.extensionFor(format);
        // A zip wraps the file under a clean base name (game.zip); single-file
        // codecs keep the full name and append their suffix (game.iso.gz).
        outputPath = format == ArchiveFormat.zip
            ? p.join(dir, '${p.basenameWithoutExtension(file)}$ext')
            : p.join(dir, '${p.basename(file)}$ext');
        if (await File(outputPath).exists()) {
          existingOutputs.add(p.basename(outputPath));
        }
      } else {
        format = ArchiveService.formatForArchive(file)!;
        outputPath = p.join(dir, p.basenameWithoutExtension(file));
        final exists = ArchiveService.isContainer(format)
            ? await Directory(outputPath).exists()
            : await File(outputPath).exists();
        if (exists) existingOutputs.add(p.basename(outputPath));
      }
      jobs.add(ArchiveJob(
        action: _action,
        inputPath: file,
        outputPath: outputPath,
        format: format,
      ));
    }

    if (existingOutputs.isNotEmpty) {
      if (!context.mounted) return;
      final loc = AppLocalizations.of(context)!;
      final confirm = await confirmDialog(
        context,
        title: loc.confirmOverwriteTitle,
        content: loc.fileConflictContent(existingOutputs.join(', ')),
        destructive: true,
      );
      if (!confirm) return;
    }

    if (context.mounted) {
      context.read<ArchiveBloc>().add(StartArchive(jobs: jobs));
    }
  }
}
