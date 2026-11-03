import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zero_app/app.dart';
import 'package:zero_app/core/notifications/notification_route.dart';
import 'package:zero_app/core/providers/auth_provider.dart';
import 'package:zero_app/features/onboarding/providers/onboarding_provider.dart';
import 'package:zero_app/features/release/presentation/screens/release_home_screen.dart';
import 'package:zero_app/features/release/presentation/screens/write_screen.dart';

import 'release_widget_harness.dart';

class _MockUser extends Mock implements User {}

class _Onboarded extends OnboardingNotifier {
  @override
  Future<bool> build() async => true;
}

void main() {
  setUpAll(ReleaseHarness.open);
  tearDownAll(ReleaseHarness.close);
  setUp(() async {
    await ReleaseHarness.reset();
    await ReleaseHarness.saveSettings();
  });

  testWidgets('app router: a notification route waiting at start opens once splash goes to /home', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ReleaseHarness.container(extra: [
      authStateProvider.overrideWith((ref) => Stream<User?>.value(_MockUser())),
      onboardingCompleteProvider.overrideWith(_Onboarded.new),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(authStateProvider, (_, __) {});
    addTearDown(sub.close);
    await c.read(authStateProvider.future);
    await c.read(onboardingCompleteProvider.future);

    c.read(notificationRouteProvider.notifier).state = '/release/write';
    final router = c.read(routerProvider);
    router.go('/home'); // スプラッシュが /home へ進むのと同じ

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          theme: ReleaseHarness.theme,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await ReleaseHarness.settle(tester);

    expect(find.byType(WriteScreen), findsOneWidget);
    expect(c.read(notificationRouteProvider), isNull);

    // 戻ると手放すタブ（タブは 5 つ）。
    router.pop();
    await ReleaseHarness.settle(tester);
    expect(find.byType(ReleaseHomeScreen), findsOneWidget);
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).items, hasLength(5));
  });
}
