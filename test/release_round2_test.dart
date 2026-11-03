import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zero_app/core/notifications/release_notification_sync.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';

import 'fakes/release_notification_fakes.dart';
import 'release/release_test_helpers.dart';

void main() {
  late Directory tmp;
  final db = ReleaseDb();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('release_round2_test');
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

  ProviderContainer make(int Function() clock) {
    final c = ProviderContainer(overrides: [
      releaseDbProvider.overrideWithValue(db),
      contentAssetLoaderProvider.overrideWithValue(const FileContentLoader()),
      releaseClockProvider.overrideWithValue(clock),
      releaseContentLangProvider.overrideWithValue(AppLang.ja),
      releaseNotificationSinkProvider.overrideWithValue(FakeSink()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('purgeAbandoned removes only old, unfinished, non-crisis rows', () async {
    var now = DateTime(2026, 11, 3, 10).millisecondsSinceEpoch;
    final c = make(() => now);
    final repo = c.read(releaseRepositoryProvider);

    final abandoned = await repo.startSession(kind: SessionKind.values.first, note: 'secret');
    final done = await repo.startSession(kind: SessionKind.values.first, note: 'kept');
    await repo.finishSession(done, 5);
    await c.read(dialogueRepositoryProvider).recordCrisis();
    now += 7 * 60 * 60 * 1000;
    final fresh = await repo.startSession(kind: SessionKind.values.first);

    expect(await repo.purgeAbandoned(), 1);
    expect(repo.sessionById(abandoned), isNull);
    expect(repo.sessionById(done), isNotNull);
    expect(repo.sessionById(fresh), isNotNull);
    expect(repo.allSessions().where((s) => s.crisis), hasLength(1));
  });

  test('refreshDayDependents expires the crisis banner after 24h without a data change', () async {
    var now = DateTime(2026, 11, 3, 10).millisecondsSinceEpoch;
    final c = make(() => now);
    final sync = c.read(releaseNotificationSyncProvider);
    await c.read(releaseSettingsRepositoryProvider).setLastCrisisAt(now);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(releaseCrisisBannerProvider), isTrue);

    now += 25 * 60 * 60 * 1000;
    expect(c.read(releaseCrisisBannerProvider), isTrue, reason: 'stale until refreshed');
    sync.refreshDayDependents();
    expect(c.read(releaseCrisisBannerProvider), isFalse);
  });
}
