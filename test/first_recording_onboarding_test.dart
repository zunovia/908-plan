// The first-recording button must finish "onboarding complete" before it
// navigates: the router's redirect (no rebuild any more) would otherwise send
// '/recording' back to onboarding while the flag is still false.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zero_app/app.dart';
import 'package:zero_app/features/onboarding/providers/onboarding_provider.dart';

class _SlowOnboarding extends OnboardingNotifier {
  @override
  Future<bool> build() async => false;

  @override
  Future<void> complete() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    state = const AsyncData(true);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('tap waits for the onboarding flag, then opens /recording',
      (tester) async {
    final c = ProviderContainer(overrides: [
      onboardingCompleteProvider.overrideWith(_SlowOnboarding.new),
    ]);
    addTearDown(c.dispose);
    final router = c.read(routerProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await c.read(onboardingCompleteProvider.future);
    router.go('/onboarding/first-recording');
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fiber_manual_record));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/recording');
    tester.takeException(); // the recording screen's own services
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
