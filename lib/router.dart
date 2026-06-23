import 'package:go_router/go_router.dart';

import 'features/boot/boot_gate.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/conditions/conditions_screen.dart';
import 'features/onboarding/disclaimer_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/tab_shell.dart';
import 'features/today/today_screen.dart';

/// Top-level routing. Deeper navigation within a tab (pickers, detail screens,
/// the add-medicine form) is done with `Navigator.push` so object arguments and
/// return values flow naturally and stay inside the active tab's stack.
GoRouter buildRouter() => GoRouter(
      initialLocation: '/boot',
      routes: [
        GoRoute(path: '/boot', builder: (c, s) => const BootGate()),
        GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
        GoRoute(path: '/disclaimer', builder: (c, s) => const DisclaimerScreen()),
        StatefulShellRoute.indexedStack(
          builder: (c, s, shell) => TabShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: '/today', builder: (c, s) => const TodayScreen())],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/calendar', builder: (c, s) => const CalendarScreen())],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/conditions', builder: (c, s) => const ConditionsScreen())],
            ),
            StatefulShellBranch(
              routes: [GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen())],
            ),
          ],
        ),
      ],
    );
