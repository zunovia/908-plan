import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/notifications/notification_route.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/onboarding/presentation/screens/splash_screen.dart';
import 'features/onboarding/presentation/screens/philosophy_screen.dart';
import 'features/onboarding/presentation/screens/metaphor_screen.dart';
import 'features/onboarding/presentation/screens/mechanism_screen.dart';
import 'features/onboarding/presentation/screens/mic_permission_screen.dart';
import 'features/onboarding/presentation/screens/notification_screen.dart';
import 'features/onboarding/presentation/screens/first_recording_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/recording/presentation/screens/recording_screen.dart';
import 'features/reports/presentation/screens/weekly_report_screen.dart';
import 'features/reports/presentation/screens/monthly_report_screen.dart';
import 'features/history/presentation/screens/history_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/demo/presentation/screens/demo_screen.dart';
import 'features/demo/presentation/screens/demo_report_screen.dart';
import 'features/release/presentation/release_routes.dart';
import 'features/release/providers/release_providers.dart';
import 'shared/widgets/zero_bottom_nav.dart';

/// Tells the router to run `redirect` again (onboarding state changed).
class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

/// The app's one GoRouter. It is built once and never rebuilt.
///
/// It used to `watch` auth and onboarding, so every sign-in created a new
/// GoRouter (back at '/'), which disposed the splash in the middle of its
/// startup work ("Cannot use ref after the widget was disposed"). Now an
/// onboarding change only re-runs `redirect` (via [RouterRefresh]), which
/// reads the current value.
///
/// Local-first: no route needs a Firebase user (all data stays on the
/// device; the anonymous sign-in runs in the background and may arrive
/// minutes later on networks that black-hole IPv6), so auth changes never
/// move the user anywhere.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh();
  ref.listen(onboardingCompleteProvider, (_, __) => refresh.refresh());
  ref.onDispose(refresh.dispose);

  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isOnboardingDone =
          ref.read(onboardingCompleteProvider).valueOrNull ?? false;
      final currentPath = state.uri.path;

      // Splash handles its own logic; the demo is open to everyone.
      if (currentPath == '/' || currentPath.startsWith('/demo')) return null;

      // Onboarding not complete → onboarding
      if (!isOnboardingDone && !currentPath.startsWith('/onboarding')) {
        return '/onboarding/philosophy';
      }

      // 通知から開く場所（起動直後はスプラッシュが /home へ進むときに回す）。
      if (currentPath == '/home') {
        final pendingRoute = ref.read(notificationRouteProvider);
        if (pendingRoute != null && pendingRoute != '/home') {
          Future.microtask(
            () => ref.read(notificationRouteProvider.notifier).state = null,
          );
          return pendingRoute;
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/',
        builder: (_, __) => const SplashScreen(),
      ),

      // Onboarding
      GoRoute(
        path: '/onboarding/philosophy',
        builder: (_, __) => const PhilosophyScreen(),
      ),
      GoRoute(
        path: '/onboarding/metaphor',
        builder: (_, __) => const MetaphorScreen(),
      ),
      GoRoute(
        path: '/onboarding/mechanism',
        builder: (_, __) => const MechanismScreen(),
      ),
      GoRoute(
        path: '/onboarding/mic-permission',
        builder: (_, __) => const MicPermissionScreen(),
      ),
      GoRoute(
        path: '/onboarding/notification',
        builder: (_, __) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/onboarding/first-recording',
        builder: (_, __) => const FirstRecordingScreen(),
      ),

      // Main (ShellRoute + BottomNav)
      ShellRoute(
        builder: (_, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, __) => const WeeklyReportScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (_, __) => const HistoryScreen(),
          ),
          // 手放す（タブ + 全画面ルート。初回説明に同意するまでは説明へ）
          releaseTabRoute(
            rootNavigatorKey: rootNavigatorKey,
            isIntroAccepted: () =>
                ref.read(releaseSettingsProvider).disclaimerAccepted,
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),

      // Monthly report (fullscreen)
      GoRoute(
        path: '/reports/monthly',
        builder: (_, __) => const MonthlyReportScreen(),
      ),

      // Recording (fullscreen)
      GoRoute(
        path: '/recording',
        builder: (_, state) {
          final durationStr = state.uri.queryParameters['duration'];
          final duration = int.tryParse(durationStr ?? '') ?? 30;
          return RecordingScreen(durationSeconds: duration);
        },
      ),

      // Demo
      GoRoute(
        path: '/demo',
        builder: (_, __) => const DemoScreen(),
      ),
      GoRoute(
        path: '/demo/report',
        builder: (_, __) => const DemoReportScreen(),
      ),
    ],
  );
});

class ZeroApp extends ConsumerStatefulWidget {
  const ZeroApp({super.key});

  @override
  ConsumerState<ZeroApp> createState() => _ZeroAppState();
}

class _ZeroAppState extends ConsumerState<ZeroApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Still no Firebase user (offline / slow network at the first start):
    // try again in the background each time the app comes back. Never
    // blocks the UI; the splash starts the first attempt.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(backgroundSignInProvider).ensureSignedIn(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // 通知のタップ: 開く場所へ移ってから null に戻す。スプラッシュ・オンボーディング中は
    // そのまま残し、/home に進むときに routerProvider の redirect が回す。
    ref.listen<String?>(notificationRouteProvider, (_, route) {
      if (route == null) return;
      final path = router.routerDelegate.currentConfiguration.uri.path;
      if (path == '/' || path.startsWith('/onboarding')) return;
      router.go(route);
      Future.microtask(
        () => ref.read(notificationRouteProvider.notifier).state = null,
      );
    });
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode),
    );
    final localeCode = ref.watch(
      settingsProvider.select((s) => s.localeCode),
    );

    return MaterialApp.router(
      title: 'Voxna',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeCode == 'system' ? null : Locale(localeCode),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      routerConfig: router,
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const ZeroBottomNav(),
    );
  }
}
