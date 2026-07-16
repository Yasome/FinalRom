import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'settings/settings_cubit.dart';
import 'blocs/conversion_bloc.dart';
import 'blocs/batch_bloc.dart';
import 'blocs/patcher_bloc.dart';
import 'blocs/hasher_bloc.dart';
import 'blocs/chd_bloc.dart';
import 'blocs/archive_bloc.dart';
import 'blocs/nsp_merge_bloc.dart';
import 'blocs/nsp_unmerge_bloc.dart';
import 'blocs/nsz_bloc.dart';
import 'services/file_service.dart';
import 'services/logger_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LoggerService.instance.init();

    FlutterError.onError = (FlutterErrorDetails details) {
      Logger.root.severe('Flutter framework error', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      Logger.root.severe('Uncaught platform error', error, stack);
      return true;
    };

    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
    }

    // Remove scratch directories orphaned by a previous crash or killed run.
    unawaited(FileService.purgeScratchDirs());

    final prefs = await SharedPreferences.getInstance();

    runApp(
      MultiBlocProvider(
        providers: [
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(prefs)),
          BlocProvider<ConversionBloc>(create: (_) => ConversionBloc()),
          BlocProvider<BatchBloc>(create: (_) => BatchBloc()),
          BlocProvider<PatcherBloc>(create: (_) => PatcherBloc()),
          BlocProvider<HasherBloc>(create: (_) => HasherBloc()),
          BlocProvider<ChdBloc>(create: (_) => ChdBloc()),
          // BlocProvider<ArchiveBloc>(create: (_) => ArchiveBloc()),
          BlocProvider<NspMergeBloc>(create: (_) => NspMergeBloc()),
          BlocProvider<NspUnmergeBloc>(create: (_) => NspUnmergeBloc()),
          BlocProvider<NszBloc>(create: (_) => NszBloc()),
        ],
        child: const CryptoApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    Logger.root.severe('Uncaught zone error', error, stack);
  });
}
// flutter clean; flutter build apk --release; flutter build windows --release 