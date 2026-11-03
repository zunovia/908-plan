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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isOnboardingDone = onboardingComplete.valueOrNull ?? false;
      final currentPath = state.uri.path;

      // Splash handles its own logic
      if (currentPath == '/') return null;

      // Not authenticated → splash
      if (!isAuthenticated && !currentPath.startsWith('/demo')) {
        return '/';
      }

      // Authenticated but onboarding not complete → onboarding
      if (isAuthenticated &&
          !isOnboardingDone &&
          !currentPath.startsWith('/onboarding') &&
          !currentPath.startsWith('/demo')) {
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

class ZeroApp extends ConsumerWidget {
  const ZeroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
