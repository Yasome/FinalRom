import 'package:go_router/go_router.dart';

import 'ui/home_screen.dart';
import 'ui/three_ds_tab.dart';
import 'ui/patcher_tab.dart';
import 'ui/hasher_tab.dart';
import 'ui/chd_tab.dart';
import 'ui/archive_tab.dart';
import 'ui/switch_tab.dart';
import 'ui/settings_screen.dart';
import 'ui/nsz_benchmark_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/3ds',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return HomeScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/3ds',
              builder: (context, state) => const ThreeDsTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/patcher',
              builder: (context, state) => const PatcherTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/hasher',
              builder: (context, state) => const HasherTab(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chd',
              builder: (context, state) => const ChdTab(),
            ),
          ],
        ),
        // StatefulShellBranch(
        //   routes: [
        //     GoRoute(
        //       path: '/archive',
        //       builder: (context, state) => const ArchiveTab(),
        //     ),
        //   ],
        // ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/switch',
              builder: (context, state) => const SwitchTab(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/nsz_benchmark',
      builder: (context, state) => const NszBenchmarkScreen(),
    ),
  ],
);
