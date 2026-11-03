import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_app/core/notifications/release_notification_scheduler.dart';
import 'package:zero_app/core/notifications/release_notification_sync.dart';
import 'package:zero_app/features/history/providers/history_provider.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';
import 'package:zero_app/features/settings/providers/settings_provider.dart';

import 'release/release_test_helpers.dart';
import 'fakes/release_notification_fakes.dart';

/// Records reschedules of the daily reminder / weekly report (1001/1002).
class _FakeSettings extends SettingsNotifier {
  int resyncs = 0;

  @override
  SettingsState build() => const SettingsState();

  @override
  Future<void> resyncNotifications() async => resyncs++;
}

void main() {
  late Directory tmp;
  final db = ReleaseDb();
  tzdata.initializeTimeZones();
  // The repository counts "today" in the device zone; use the same zone here.
  final zone = tz.getLocation('Asia/Tokyo');
  final now = DateTime(2026, 11, 3, 10).millisecondsSinceEpoch;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('release_sync_test');
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

  ({ProviderContainer c, FakeSink sink, _FakeSettings settings}) setup({ReleaseTimeZoneResolver? resolver}) {
    final sink = FakeSink();
    final settings = _FakeSettings();
    final c = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => settings),
      releaseDbProvider.overrideWithValue(db),
      contentAssetLoaderProvider.overrideWithValue(const FileContentLoader()),
      releaseClockProvider.overrideWithValue(() => now),
      releaseContentLangProvider.overrideWithValue(AppLang.ja),
      releaseNotificationSinkProvider.overrideWithValue(sink),
      releaseNotificationZoneProvider.overrideWith((ref) => zone),
      releaseTimeZoneResolverProvider.overrideWithValue(resolver ?? () async => zone),
    ]);
    addTearDown(c.dispose);
    return (c: c, sink: sink, settings: settings);
  }

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 600));

  test('resync uses the stored settings, notifications.json (ja) and the ja channel name', () async {
    final t = setup();
    final sync = t.c.read(releaseNotificationSyncProvider);
    await t.c.read(releaseSettingsProvider.notifier).setCheckinMorning(enabled: true, time: '07:30');
    await sync.resync();
    expect(t.sink.cancelled, containsAll(ReleaseNotificationScheduler.allIds));
    expect(t.sink.scheduled, hasLength(ReleaseNotificationScheduler.occurrencesPerReminder));
    final first = t.sink.scheduled.first;
    expect(first['id'], 2001);
    expect(first['channel'], '手放す');
    expect(first['payload'], '/release/quick');
    expect((first['body']! as String).isNotEmpty, isTrue);
  });

  test('changing a release setting reschedules by itself', () async {
    final t = setup();
    final sync = t.c.read(releaseNotificationSyncProvider);
    await t.c.read(releaseSettingsProvider.notifier).setCheckinEvening(enabled: true);
    await settle();
    expect(sync.runs, greaterThanOrEqualTo(1));
    expect(t.sink.scheduled.map((e) => e['payload']).toSet(), {'/release/write'});

    // Settings that do not affect notifications do not reschedule.
    final runs = sync.runs;
    await t.c.read(releaseSettingsProvider.notifier).setGoalCount(54);
    await settle();
    expect(sync.runs, runs);
  });

  test('a release today removes today\'s zero-day reminder', () async {
    final t = setup();
    final sync = t.c.read(releaseNotificationSyncProvider);
    await t.c.read(releaseSettingsProvider.notifier).setZeroDay(enabled: true, time: '20:00');
    await sync.resync();
    final todayAt = tz.TZDateTime(zone, 2026, 11, 3, 20);
    expect(t.sink.scheduled.first['at'], todayAt);

    t.sink.scheduled.clear();
    final repo = t.c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.values.first);
    await repo.finishSession(id, 3);
    await settle();
    expect(t.sink.scheduled, isNotEmpty);
    expect(t.sink.scheduled.any((e) => e['at'] == todayAt), isFalse);
  });

  test('cleared release data (account deletion) leaves nothing scheduled', () async {
    final t = setup();
    final sync = t.c.read(releaseNotificationSyncProvider);
    await t.c.read(releaseSettingsProvider.notifier).setCheckinMorning(enabled: true);
    await sync.resync();
    expect(t.sink.scheduled, isNotEmpty);

    await db.clearAll();
    t.c.invalidate(releaseSettingsProvider);
    t.sink.scheduled.clear();
    await sync.cancelAll();
    await sync.resync();
    expect(t.sink.scheduled, isEmpty);
    expect(t.sink.cancelled, containsAll(ReleaseNotificationScheduler.allIds));
  });

  test('history: release counts by day follow new sessions', () async {
    final t = setup();
    final sub = t.c.listen(historyReleaseCountsProvider, (_, __) {}, fireImmediately: true);
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(t.c.read(historyReleaseCountsProvider).valueOrNull, isEmpty);

    final repo = t.c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.values.first);
    await repo.finishSession(id, 27);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(t.c.read(historyReleaseCountsProvider).valueOrNull, {DateTime(2026, 11, 3): 1});
  });

  group('time zone on resume', () {
    final previousLocal = tz.local;
    tearDown(() => tz.setLocalLocation(previousLocal));

    test('a travelling user: the zone is re-resolved before the window is rebuilt', () async {
      final paris = tz.getLocation('Europe/Paris');
      var current = zone;
      final t = setup(resolver: () async => current);
      final sync = t.c.read(releaseNotificationSyncProvider);
      await t.c.read(releaseSettingsProvider.notifier).setCheckinMorning(enabled: true, time: '07:30');
      await sync.resync();
      expect((t.sink.scheduled.first['at']! as tz.TZDateTime).location.name, 'Asia/Tokyo');

      current = paris;
      t.sink.scheduled.clear();
      await sync.onResume();
      await settle();
      expect(t.c.read(releaseNotificationZoneProvider).name, 'Europe/Paris');
      expect(tz.local.name, 'Europe/Paris');
      final first = t.sink.scheduled.first['at']! as tz.TZDateTime;
      expect(first.location.name, 'Europe/Paris');
      expect((first.hour, first.minute), (7, 30));
      // The daily reminder and weekly report move to the new zone too.
      expect(t.settings.resyncs, 1);
    });

    test('same zone on resume: the daily / weekly reminders are left alone', () async {
      final t = setup();
      final sync = t.c.read(releaseNotificationSyncProvider);
      await sync.onResume();
      await settle();
      expect(t.settings.resyncs, 0);
    });

    test('an unresolvable zone keeps the previous one and still reschedules', () async {
      final t = setup(resolver: () async => throw StateError('no zone'));
      final sync = t.c.read(releaseNotificationSyncProvider);
      await t.c.read(releaseSettingsProvider.notifier).setCheckinMorning(enabled: true, time: '07:30');
      await settle();
      t.sink.scheduled.clear();
      expect(await sync.refreshTimeZone(), isFalse);
      await sync.onResume();
      await settle();
      expect(t.c.read(releaseNotificationZoneProvider).name, 'Asia/Tokyo');
      expect(t.sink.scheduled, isNotEmpty);
    });

    test('a resolver that never answers times out and keeps the zone', () async {
      final t = setup(resolver: () => Completer<tz.Location?>().future);
      final sync = t.c.read(releaseNotificationSyncProvider);
      expect(await sync.refreshTimeZone(timeout: const Duration(milliseconds: 50)), isFalse);
      expect(t.c.read(releaseNotificationZoneProvider).name, 'Asia/Tokyo');
    });

    test('a null zone (platform could not answer) is ignored', () async {
      final t = setup(resolver: () async => null);
      final sync = t.c.read(releaseNotificationSyncProvider);
      expect(await sync.refreshTimeZone(), isFalse);
      expect(t.c.read(releaseNotificationZoneProvider).name, 'Asia/Tokyo');
    });
  });
}
