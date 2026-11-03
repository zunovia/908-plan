import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';

import 'release_test_helpers.dart';

void main() {
  late Directory tmp;
  final db = ReleaseDb();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('release_providers_test');
    Hive.init(tmp.path);
    await db.init();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async => db.clearAll());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      releaseDbProvider.overrideWithValue(db),
      contentAssetLoaderProvider.overrideWithValue(const FileContentLoader()),
      releaseClockProvider.overrideWithValue(() => DateTime(2026, 10, 18, 10).millisecondsSinceEpoch),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('releaseDbProvider throws when not overridden', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(() => c.read(releaseDbProvider), throwsA(anything));
  });

  test('settings notifier persists and reflects saves from other paths', () async {
    final c = container();
    expect(c.read(releaseSettingsProvider).goalCount, 27);
    await c.read(releaseSettingsProvider.notifier).setGoalCount(108);
    expect(c.read(releaseSettingsProvider).goalCount, 108);
    await c.read(releaseSettingsProvider.notifier).acceptDisclaimer();
    expect(c.read(releaseSettingsProvider).disclaimerAccepted, isTrue);

    // DialogueRepository が保存した lastCrisisAt も state に届く。
    await c.read(dialogueRepositoryProvider).recordCrisis();
    await Future<void>.delayed(Duration.zero);
    expect(c.read(releaseSettingsProvider).lastCrisisAt, greaterThan(0));
    expect(c.read(releaseCrisisBannerProvider), isTrue);
  });

  test('summary stream updates after a finished session', () async {
    final c = container();
    final sub = c.listen(releaseSummaryProvider, (_, __) {});
    addTearDown(sub.close);
    expect((await c.read(releaseSummaryProvider.future)).monthCount, 0);
    final repo = c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.WORDS4);
    await repo.finishSession(id, 3);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(releaseSummaryProvider).value?.monthCount, 1);
  });

  test('domain provider builds from bundled content', () async {
    final c = container();
    final d = await c.read(releaseDomainProvider.future);
    expect(d.safetyGate.isFreeTextAllowed(AppLang.ja), isTrue);
    expect(d.content.cards[AppLang.en], isNotEmpty);
  });
}
