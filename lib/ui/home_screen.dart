import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:final_rom/l10n/app_localizations.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../services/file_service.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';

class HomeScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const HomeScreen({super.key, required this.navigationShell});

  void _onTabTapped(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        final bodyContent = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: navigationShell,
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(loc.appTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: isDesktop
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: _onTabTapped,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.enhanced_encryption_outlined),
                          selectedIcon: const Icon(Icons.enhanced_encryption),
                          label: Text(loc.tabThreeDs),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.build_outlined),
                          selectedIcon: const Icon(Icons.build),
                          label: Text(loc.tabPatcher),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.tag_outlined),
                          selectedIcon: const Icon(Icons.tag),
                          label: Text(loc.tabHasher),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.album_outlined),
                          selectedIcon: const Icon(Icons.album),
                          label: Text(loc.tabChd),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.videogame_asset_outlined),
                          selectedIcon: const Icon(Icons.videogame_asset),
                          label: Text(loc.tabSwitch),
                        ),
                      ],
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: bodyContent),
                  ],
                )
              : bodyContent,
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onTabTapped,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.enhanced_encryption_outlined),
                      selectedIcon: const Icon(Icons.enhanced_encryption),
                      label: loc.tabThreeDs,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.build_outlined),
                      selectedIcon: const Icon(Icons.build),
                      label: loc.tabPatcher,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.tag_outlined),
                      selectedIcon: const Icon(Icons.tag),
                      label: loc.tabHasher,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.album_outlined),
                      selectedIcon: const Icon(Icons.album),
                      label: loc.tabChd,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.videogame_asset_outlined),
                      selectedIcon: const Icon(Icons.videogame_asset),
                      label: loc.tabSwitch,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Shows a "Saved" SnackBar with an optional Share action, used after a
/// mobile operation finishes. The file is already written to a browsable folder;
/// sharing is offered as a one-tap convenience rather than popped automatically.
void showSavedSnackBar(BuildContext context, String outputPath, {String? trailing}) {
  final loc = AppLocalizations.of(context)!;
  final fileName = outputPath.split(RegExp(r'[\\/]')).last;
  final message = trailing == null
      ? loc.savedToFile(fileName)
      : '${loc.savedToFile(fileName)} ($trailing)';

  if (FileService.isDesktop) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: loc.btnShowInFolder,
          onPressed: () => FileService.openDirectory(outputPath),
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: loc.btnShare,
          onPressed: () => FileService.shareFile(outputPath),
        ),
      ),
    );
  }
}

/// Shows a themed error SnackBar. Routes through [ColorScheme.error] so the
/// styling adapts to light/dark and the user's seed color, replacing the many
/// ad-hoc `backgroundColor: Colors.red` SnackBars.
void showErrorSnackBar(BuildContext context, String message) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: SelectableText(message, style: TextStyle(color: scheme.onError)),
      backgroundColor: scheme.error,
      duration: const Duration(seconds: 10),
    ),
  );
}

/// Shows a neutral, themed informational SnackBar (e.g. "Cancelling…").
void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
}

/// Shows a themed warning SnackBar, using the app's semantic warning color so
/// it stays legible in light and dark mode.
void showWarningSnackBar(BuildContext context, String message) {
  final semantic = context.semantic;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: TextStyle(color: semantic.onWarning)),
      backgroundColor: semantic.warning,
      duration: const Duration(seconds: 5),
    ),
  );
}

// ---------------------------------------------------------
// Drag & Drop Target Helper Widget
// ---------------------------------------------------------
class DragDropTarget extends StatefulWidget {
  final Widget child;
  final ValueChanged<List<String>> onFilesDropped;
  final String hintText;

  const DragDropTarget({
    super.key,
    required this.child,
    required this.onFilesDropped,
    required this.hintText,
  });

  @override
  State<DragDropTarget> createState() => _DragDropTargetState();
}

class _DragDropTargetState extends State<DragDropTarget> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Drag-and-drop is desktop-only; desktop_drop has no Android backing, so the
    // file picker remains the import path there. Never wrap the child in a
    // DropTarget on Android.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return widget.child;
    }
    if (!TickerMode.valuesOf(context).enabled) {
      return widget.child;
    }
    final loc = AppLocalizations.of(context)!;
    return DropTarget(
      onDragEntered: (_) {
        setState(() => _isDragging = true);
      },
      onDragExited: (_) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        final paths = await FileService.handleDroppedItems(
          details.files.map((file) => file.path).toList(),
        );
        if (paths.isNotEmpty) {
          widget.onFilesDropped(paths);
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isDragging ? 1.0 : 0.0,
                child: Container(
                  // ignore: deprecated_member_use
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.92),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(24.0),
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(24.0),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 16.0,
                            spreadRadius: 2.0,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 64.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16.0),
                          Text(
                            widget.hintText,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            loc.dragDropSubtext,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
