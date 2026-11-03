import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/release_settings.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';
import 'package:zero_app/features/settings/presentation/widgets/release_settings_section.dart';

import 'release_widget_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await ReleaseHarness.open();
  });
  tearDownAll(ReleaseHarness.close);
  setUp(() async {
    await ReleaseHarness.reset();
    await ReleaseHarness.saveSettings();
  });

  Future<void> pumpSection(WidgetTester tester, ProviderContainer c) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: ReleaseHarness.theme,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: ReleaseSettingsSection()),
          ),
        ),
      ),
    );
    await ReleaseHarness.settle(tester);
  }

  Future<void> tapDeleteAll(WidgetTester tester) async {
    final row = find.text(l10n.rel_settings_delete_all);
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await ReleaseHarness.settle(tester, frames: 4);
  }

  testWidgets('deleting all records also clears the crisis time and confirms with a SnackBar',
      (tester) async {
    // A crisis an hour ago (banner showing) and a finished session.
    final base = ReleaseSettings.fromMap(ReleaseHarness.db.settings.get(ReleaseDb.settingsKey));
    await ReleaseHarness.db.settings.put(
      ReleaseDb.settingsKey,
      base.copyWith(lastCrisisAt: fixedNow - const Duration(hours: 1).inMilliseconds).toMap(),
    );
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    final repo = c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.values.first);
    await repo.finishSession(id, 27);
    expect(repo.allSessions(), isNotEmpty);
    expect(c.read(releaseCrisisBannerProvider), isTrue);

    await pumpSection(tester, c);
    await tapDeleteAll(tester);
    expect(find.text(l10n.rel_settings_delete_all_confirm_title), findsOneWidget);
    await tester.tap(find.text(l10n.rel_settings_delete_all_confirm_action));
    await ReleaseHarness.settle(tester, frames: 6);

    expect(repo.allSessions(), isEmpty);
    expect(c.read(releaseSettingsProvider).lastCrisisAt, 0);
    expect(c.read(releaseCrisisBannerProvider), isFalse);
    // Stored too (survives a restart).
    expect(
      ReleaseSettings.fromMap(ReleaseHarness.db.settings.get(ReleaseDb.settingsKey)).lastCrisisAt,
      0,
    );
    expect(find.text(l10n.rel_vx_records_deleted), findsOneWidget);
    // Other settings are kept.
    expect(c.read(releaseSettingsProvider).disclaimerAccepted, isTrue);
  });

  testWidgets('cancelling keeps the records and the crisis time, and shows no SnackBar',
      (tester) async {
    final crisisAt = fixedNow - const Duration(hours: 2).inMilliseconds;
    final base = ReleaseSettings.fromMap(ReleaseHarness.db.settings.get(ReleaseDb.settingsKey));
    await ReleaseHarness.db.settings.put(
      ReleaseDb.settingsKey,
      base.copyWith(lastCrisisAt: crisisAt).toMap(),
    );
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    final repo = c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.values.first);
    await repo.finishSession(id, 27);

    await pumpSection(tester, c);
    await tapDeleteAll(tester);
    await tester.tap(find.text(l10n.rel_settings_delete_all_cancel));
    await ReleaseHarness.settle(tester, frames: 6);

    expect(repo.allSessions(), isNotEmpty);
    expect(c.read(releaseSettingsProvider).lastCrisisAt, crisisAt);
    expect(find.text(l10n.rel_vx_records_deleted), findsNothing);
  });
}
