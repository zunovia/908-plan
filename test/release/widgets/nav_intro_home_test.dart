import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/presentation/screens/release_home_screen.dart';
import 'package:zero_app/features/release/presentation/screens/release_intro_screen.dart';
import 'package:zero_app/features/release/presentation/screens/write_screen.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';

import 'release_widget_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUpAll(ReleaseHarness.open);
  tearDownAll(ReleaseHarness.close);
  setUp(ReleaseHarness.reset);

  testWidgets('bottom nav has 5 tabs with 手放す 4th', (tester) async {
    await ReleaseHarness.saveSettings();
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: '/home');

    final nav = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(nav.items, hasLength(5));
    expect(nav.items[3].label, l10n.rel_vx_tab_label);
    expect(nav.currentIndex, 0);

    await tester.tap(find.text(l10n.rel_vx_tab_label));
    await ReleaseHarness.settle(tester);
    expect(find.byType(ReleaseHomeScreen), findsOneWidget);
    expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, 3);
  });

  testWidgets('release tab shows the intro until agreed, then home', (tester) async {
    await ReleaseHarness.saveSettings(accepted: false);
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: '/release');

    expect(find.byType(ReleaseIntroScreen), findsOneWidget);
    expect(find.text(l10n.rel_onboarding_p1_headline), findsOneWidget);
    expect(find.text(l10n.rel_onboarding_origin_note), findsOneWidget);

    final agree = find.text(l10n.rel_vx_intro_agree);
    await tester.scrollUntilVisible(agree, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(agree);
    await ReleaseHarness.settle(tester);

    expect(c.read(releaseSettingsProvider).disclaimerAccepted, isTrue);
    expect(find.byType(ReleaseIntroScreen), findsNothing);
    expect(find.byType(ReleaseHomeScreen), findsOneWidget);
  });

  testWidgets('intro gate also guards deep links like /release/write and returns there', (tester) async {
    await ReleaseHarness.saveSettings(accepted: false);
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: '/release/write');
    expect(find.byType(ReleaseIntroScreen), findsOneWidget);

    final agree = find.text(l10n.rel_vx_intro_agree);
    await tester.scrollUntilVisible(agree, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(agree);
    await ReleaseHarness.settle(tester);
    expect(find.byType(WriteScreen), findsOneWidget);
  });

  testWidgets('home shows month count, today card and the big button; button opens write', (tester) async {
    await ReleaseHarness.saveSettings();
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    final repo = c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.WORDS4, note: '返信がない', tags: const ['人']);
    await repo.finishSession(id, 27);

    await ReleaseHarness.pump(tester, c, initialLocation: '/release');

    expect(find.text(l10n.rel_home_month_count(1)), findsOneWidget);
    expect(find.text(l10n.rel_home_today_card), findsOneWidget);
    final letGo = find.widgetWithText(FilledButton, l10n.rel_home_letgo);
    expect(letGo, findsOneWidget);
    expect(find.text('返信がない'), findsOneWidget); // 最近の記録
    expect(find.text('人 1'), findsOneWidget); // よく手放した記憶

    await tester.tap(letGo);
    await ReleaseHarness.settle(tester);
    expect(find.byType(WriteScreen), findsOneWidget);
    expect(find.text(l10n.rel_write_title), findsOneWidget);
  });
}
