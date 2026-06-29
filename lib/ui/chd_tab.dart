import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:chdman_ffi/chdman_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:final_rom/l10n/app_localizations.dart';

import '../services/file_service.dart';
import '../services/chd_worker.dart';
import '../blocs/chd_bloc.dart';
import '../blocs/queue_progress.dart';
import '../settings/settings_cubit.dart';
import '../settings/app_settings.dart';
import 'home_screen.dart';
import 'android_file_picker.dart';
import 'app_spacing.dart';
import 'widgets/dialogs.dart';

class ChdTab extends StatefulWidget {
  const ChdTab({super.key});

  @override
  State<ChdTab> createState() => _ChdTabState();
}

class _ChdTabState extends State<ChdTab> {
  ChdAction _action = ChdAction.create;

  // CD (false) or DVD (true) output for create jobs; ignored by extract.
  bool _createDvd = false;

  // The queue of files to process, one after another.
  List<String> _selectedFiles = [];

  bool _isValidForAction(String path) {
    final ext = p.extension(path).toLowerCase();
    if (_action == ChdAction.create) {
      return ext == '.cue' || ext == '.bin' || ext == '.iso';
    }
    return ext == '.chd';
  }

  void _addFiles(Iterable<String> paths) {
    final valid = paths.where(_isValidForAction);
    if (valid.isEmpty) return;
    setState(() {
      _selectedFiles.addAll(valid);
      _selectedFiles = _selectedFiles.toSet().toList(); // unique
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return DragDropTarget(
      hintText: _action == ChdAction.create ? loc.chdCreateHint : loc.chdExtractHint,
      onFilesDropped: (paths) {
        final hadValid = paths.any(_isValidForAction);
        _addFiles(paths);
        if (!hadValid) showErrorSnackBar(context, loc.errInvalidFileType);
      },
      child: BlocConsumer<ChdBloc, ChdState>(
        listener: (context, state) {
          if (state is ChdBatchDone) {
            _onBatchDone(context, loc, state);
          }
        },
        builder: (context, state) {
          final isRunning = state is ChdRunning || state is ChdProgress;
          final double? progressValue = state is ChdProgress ? state.fraction : null;
          final QueuePosition? position = state is ChdProgress ? state.position : null;
          final statusLabel =
              _action == ChdAction.create ? loc.statusCompressing : loc.statusExtracting;
          return Padding(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ChdAction>(
                  segments: [
                    ButtonSegment(
                      value: ChdAction.create,
                      label: Text(loc.chdCreate),
                      icon: const Icon(Icons.compress),
                    ),
                    ButtonSegment(
                      value: ChdAction.extract,
                      label: Text(loc.chdExtract),
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
                if (_action == ChdAction.create)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(loc.chdDiscType),
                    subtitle: Text(
                        _createDvd ? loc.chdDiscTypeDvd : loc.chdDiscTypeCd),
                    value: _createDvd,
                    onChanged: isRunning
                        ? null
                        : (value) => setState(() => _createDvd = value),
                  ),
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
                          context.read<ChdBloc>().add(CancelChd());
                          showInfoSnackBar(context, loc.statusCancelling);
                        },
                        child: Text(loc.btnCancel),
                      )
                    else
                      FilledButton(
                        onPressed: _selectedFiles.isEmpty ? null : () => _runAction(context),
                        child: Text(_action == ChdAction.create ? loc.btnCreate : loc.btnExtract),
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
    final percent = progressValue != null ? ' ${(progressValue * 100).toStringAsFixed(0)}%' : '';
    if (position != null && position.isBatch) {
      return '${loc.queueFileProgress(position.currentIndex, position.total)} · $statusLabel$percent';
    }
    return '$statusLabel$percent';
  }

  void _onBatchDone(BuildContext context, AppLocalizations loc, ChdBatchDone state) {
    final total = state.results.length;
    if (total == 0) return;
    final timeStr = '${(state.duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
    if (state.results.hasFailures) {
      // Surface the first error for context, plus the failed/total count.
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
        showSavedSnackBar(context, state.results.first.outputPath ?? '', trailing: timeStr);
      } else {
        showInfoSnackBar(context, '${loc.queueDoneSummary(ok, total)} ($timeStr)');
      }
    }
  }

  Future<void> _browse(BuildContext context) async {
    List<String> files = [];
    if (Platform.isAndroid && context.mounted) {
      final picked = await AndroidFilePicker.pickFiles(context,
          allowedExtensions: ['cue', 'bin', 'iso', 'chd']);
      if (picked != null) files.addAll(picked);
    } else {
      files = await FileService.pickFiles(
          allowMultiple: true, allowedExtensions: ['cue', 'bin', 'iso', 'chd']);
    }
    _addFiles(files);
  }

  Future<void> _runAction(BuildContext context) async {
    if (_selectedFiles.isEmpty) return;
    final settings = context.read<SettingsCubit>().state;

    // Resolve the output directory once (it is the same policy for every file).
    Future<String> outputDirFor(String inputFile) async {
      if (settings.outputLocation == OutputLocation.customDir) {
        return settings.customOutputDir ?? p.dirname(inputFile);
      } else if (settings.outputLocation == OutputLocation.appDocuments) {
        return FileService.getMobileOutputDirectory();
      }
      return p.dirname(inputFile);
    }

    // Build one job per selected file.
    final jobs = <ChdJob>[];
    final existingOutputs = <String>[];
    for (final file in _selectedFiles) {
      final dir = await outputDirFor(file);
      final baseName = p.basenameWithoutExtension(file);
      String outputPath;
      String? outputBinPath;
      if (_action == ChdAction.create) {
        outputPath = p.join(dir, '$baseName.chd');
      } else {
        outputPath = p.join(dir, '$baseName.cue');
        outputBinPath = p.join(dir, '$baseName.bin');
      }
      if (await File(outputPath).exists() ||
          (outputBinPath != null && await File(outputBinPath).exists())) {
        existingOutputs.add(p.basename(outputPath));
      }
      jobs.add(ChdJob(
        action: _action,
        inputPath: file,
        outputPath: outputPath,
        outputBinPath: outputBinPath,
      ));
    }

    // A single confirmation for the whole queue if any output already exists.
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
      final tuning = settings.resolveTuning();
      context.read<ChdBloc>().add(
            StartChd(
              jobs: jobs,
              force: true,
              createDvd: _createDvd,
              options: ChdOptions(
                codecs: tuning.chdCodecs,
                numProcessors: tuning.chdNumProcessors,
                hunkBytes: tuning.chdHunkBytes,
              ),
            ),
          );
    }
  }
}
