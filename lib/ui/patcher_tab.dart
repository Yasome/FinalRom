import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:final_rom/l10n/app_localizations.dart';

import '../blocs/patcher_bloc.dart';
import '../patcher/patcher.dart';
import '../patcher/patcher_factory.dart';
import '../services/file_service.dart';
import '../services/patch_verifier.dart';
import '../settings/settings_cubit.dart';
import '../settings/app_settings.dart';
import 'home_screen.dart'; // For DragDropTarget
import 'android_file_picker.dart';
import 'app_spacing.dart';
import 'theme.dart';
import 'dart:io';

class PatcherTab extends StatefulWidget {
  const PatcherTab({super.key});
  @override
  State<PatcherTab> createState() => _PatcherTabState();
}

class _PatcherTabState extends State<PatcherTab> {
  String? _selectedRomFile;
  String? _selectedPatchFile;
  CompatibilityResult _compatibility = CompatibilityResult.unverifiable;
  bool _isCheckingCompatibility = false;

  void _checkCompatibility() async {
    if (_selectedRomFile == null || _selectedPatchFile == null) {
      setState(() {
        _compatibility = CompatibilityResult.unverifiable;
        _isCheckingCompatibility = false;
      });
      return;
    }

    setState(() {
      _isCheckingCompatibility = true;
    });

    final result = await PatchVerifier.checkCompatibility(_selectedPatchFile!, _selectedRomFile!);

    if (mounted) {
      setState(() {
        _compatibility = result;
        _isCheckingCompatibility = false;
      });
    }
  }

  void _handleRomDrop(List<String> paths) {
    if (paths.length == 1) {
      setState(() => _selectedRomFile = paths.first);
      _checkCompatibility();
    } else {
      _assignByType(paths);
    }
  }

  void _handlePatchDrop(List<String> paths) {
    if (paths.length == 1) {
      setState(() => _selectedPatchFile = paths.first);
      _checkCompatibility();
    } else {
      _assignByType(paths);
    }
  }

  void _assignByType(List<String> paths) {
    for (final path in paths) {
      if (PatcherFactory.isSupportedPatch(path)) {
        setState(() => _selectedPatchFile = path);
      } else {
        setState(() => _selectedRomFile = path);
      }
    }
    _checkCompatibility();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return BlocConsumer<PatcherBloc, PatcherState>(
        listener: (context, state) {
          if (state is PatcherSuccess) {
            final timeStr = '${(state.duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
            showSavedSnackBar(context, state.outputPath, trailing: timeStr);
          } else if (state is PatcherFailure) {
            showErrorSnackBar(context, state.error);
          }
        },
        builder: (context, state) {
          final isRunning = state is PatcherRunning;
          return Padding(
            padding: AppSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DragDropTarget(
                          hintText: loc.dragDropHintRom,
                          onFilesDropped: _handleRomDrop,
                          child: Card(
                            child: Padding(
                              padding: AppSpacing.card,
                              child: Column(
                                children: [
                                  Text(loc.romFile, style: Theme.of(context).textTheme.titleSmall),
                                  Text(
                                    _selectedRomFile != null ? p.basename(_selectedRomFile!) : loc.errNoFileSelected,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  AppSpacing.gapSm,
                                  FilledButton.icon(
                                    icon: const Icon(Icons.folder_open),
                                    label: Text(loc.btnBrowseRom),
                                    onPressed: isRunning ? null : () async {
                                      String? file;
                                      if (Platform.isAndroid && context.mounted) {
                                        file = await AndroidFilePicker.pickFile(context);
                                      } else {
                                        file = await FileService.pickAnyFile();
                                      }
                                      if (file != null) {
                                        setState(() => _selectedRomFile = file);
                                        _checkCompatibility();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.gapMd,
                        DragDropTarget(
                          hintText: loc.dragDropHintPatch,
                          onFilesDropped: _handlePatchDrop,
                          child: Card(
                            child: Padding(
                              padding: AppSpacing.card,
                              child: Column(
                                children: [
                                  Text(loc.patchFile, style: Theme.of(context).textTheme.titleSmall),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _selectedPatchFile != null ? p.basename(_selectedPatchFile!) : loc.errNoPatchSelected,
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      if (_selectedPatchFile != null) ...[
                                        const SizedBox(width: 8),
                                        if (PatcherFactory.isSupportedPatch(_selectedPatchFile!))
                                          Chip(
                                            label: Text(PatcherFactory.formatName(_selectedPatchFile!) ?? ''),
                                            visualDensity: VisualDensity.compact,
                                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                          )
                                        else
                                          Text(loc.errUnsupportedPatch, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                      ],
                                    ],
                                  ),
                                  AppSpacing.gapSm,
                                  FilledButton.icon(
                                    icon: const Icon(Icons.description),
                                    label: Text(loc.btnBrowsePatch),
                                    onPressed: isRunning ? null : () async {
                                      String? file;
                                      if (Platform.isAndroid && context.mounted) {
                                        file = await AndroidFilePicker.pickFile(context);
                                      } else {
                                        file = await FileService.pickPatchFile();
                                      }
                                      if (file != null) {
                                        setState(() => _selectedPatchFile = file);
                                        _checkCompatibility();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_selectedRomFile != null && _selectedPatchFile != null) ...[
                          AppSpacing.gapMd,
                          _buildCompatibilityBanner(loc),
                        ],
                        AppSpacing.gapLg,
                        if (isRunning) ...[
                          const LinearProgressIndicator(),
                          AppSpacing.gapSm,
                          Text(loc.statusPatching, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                          AppSpacing.gapLg,
                        ] else if (state is PatcherSuccess) ...[
                          Text(
                            '${loc.statusDone} in ${(state.duration.inMilliseconds / 1000).toStringAsFixed(2)}s',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.semantic.success),
                          ),
                          if (state.report != null) ...[
                            AppSpacing.gapMd,
                            Card(
                              elevation: 0,
                              // ignore: deprecated_member_use
                              color: Theme.of(context).colorScheme.surfaceVariant,
                              child: Padding(
                                padding: AppSpacing.card,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(loc.patchReportFormat(state.report!.format), style: Theme.of(context).textTheme.titleSmall),
                                    AppSpacing.gapSm,
                                    if (state.report!.checks.isEmpty)
                                      Text(loc.patchReportNoChecksums)
                                    else
                                      ...state.report!.checks.map((check) {
                                        return Row(
                                          children: [
                                            if (check.outcome == CheckOutcome.passed)
                                              Icon(Icons.check_circle, color: context.semantic.success, size: 20)
                                            else
                                              Icon(Icons.remove_circle_outline, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                                            const SizedBox(width: 8),
                                            Text(check.label),
                                            const Spacer(),
                                            if (check.outcome == CheckOutcome.passed)
                                              Text(loc.checkOutcomePassed, style: TextStyle(color: context.semantic.success))
                                            else
                                              Text(loc.checkOutcomeSkipped, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                          ],
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          AppSpacing.gapLg,
                        ],
                      ],
                    ),
                  ),
                ),
                AppSpacing.gapMd,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (isRunning)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: () => context.read<PatcherBloc>().add(CancelPatching()),
                        child: Text(loc.btnCancel),
                      )
                    else
                      FilledButton(
                        onPressed: (_selectedRomFile == null || _selectedPatchFile == null || !PatcherFactory.isSupportedPatch(_selectedPatchFile!))
                            ? null
                            : () => _applyPatch(context),
                        child: Text(loc.btnPatch),
                      ),
                  ],
                ),
                AppSpacing.gapMd,
              ],
            ),
          );
        },
      );
  }

  Future<void> _applyPatch(BuildContext context) async {
    final settings = context.read<SettingsCubit>().state;
    String baseFolder = p.dirname(_selectedRomFile!);
    if (settings.outputLocation == OutputLocation.customDir) {
      baseFolder = settings.customOutputDir ?? baseFolder;
    } else if (settings.outputLocation == OutputLocation.appDocuments) {
      baseFolder = await FileService.getMobileOutputDirectory();
    }
    final baseName = p.basenameWithoutExtension(_selectedRomFile!);
    final ext = p.extension(_selectedRomFile!);
    final outPath = await FileService.generateUniqueOutputPath(baseFolder, '${baseName}_patched', ext);
    
    if (context.mounted) {
      context.read<PatcherBloc>().add(StartPatching(
        romPath: _selectedRomFile!,
        patchPath: _selectedPatchFile!,
        outputPath: outPath,
        ignoreChecksum: settings.ignoreChecksum,
      ));
    }
  }

  Widget _buildCompatibilityBanner(AppLocalizations loc) {
    if (_isCheckingCompatibility) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(loc.patchCompatibilityChecking, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
    }

    IconData icon;
    Color color;
    String text;
    // Neutral states (unverifiable) should not be emphasized like a status color.
    bool emphasized = true;

    switch (_compatibility) {
      case CompatibilityResult.compatible:
        icon = Icons.check_circle;
        color = context.semantic.success;
        text = loc.patchCompatibilityCompatible;
        break;
      case CompatibilityResult.incompatible:
        icon = Icons.warning;
        color = context.semantic.warning;
        text = loc.patchCompatibilityIncompatible;
        break;
      case CompatibilityResult.unverifiable:
        icon = Icons.info_outline;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        text = loc.patchCompatibilityUnverifiable;
        emphasized = false;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: color.withAlpha(76)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: emphasized ? color : null,
                  fontWeight: emphasized ? FontWeight.w500 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
