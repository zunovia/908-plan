import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
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
import 'shared/widgets/zero_bottom_nav.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
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
