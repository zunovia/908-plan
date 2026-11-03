// Account deletion (Settings → アカウント削除): the device data is deleted
// first and unconditionally; the Firebase user afterwards, with a timeout.
// Regression for the Pixel 6a report where a hanging Firebase call (IPv6
// black-holed Wi-Fi) kept every recording and setting on the device.

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_app/core/audio/sound_manager.dart';
import 'package:zero_app/core/audio/voice_clip_service.dart';
import 'package:zero_app/core/notifications/notification_service.dart';
import 'package:zero_app/core/notifications/release_notification_scheduler.dart';
import 'package:zero_app/core/notifications/release_notification_sync.dart';
import 'package:zero_app/core/providers/audio_providers.dart';
import 'package:zero_app/core/providers/auth_provider.dart';
import 'package:zero_app/core/providers/notification_providers.dart';
import 'package:zero_app/core/providers/storage_providers.dart';
import 'package:zero_app/core/storage/local_db.dart';
import 'package:zero_app/core/storage/secure_storage.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';
import 'package:zero_app/features/settings/providers/settings_provider.dart';

import 'fakes/release_notification_fakes.dart';
import 'release/release_test_helpers.dart';

/// Never touched: [_FakeAuth] overrides everything AuthService does.
class _NoFirebase implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('FirebaseAuth is not used in this test');
}

/// AuthService whose delete / sign-out are scripted per test.
class _FakeAuth extends AuthService {
  _FakeAuth(this.onDelete) : super(_NoFirebase());

  final Future<void> Function() onDelete;
  int deleteCalls = 0;
  int signOutCalls = 0;

  @override
  Future<void> deleteAccount() {
    deleteCalls++;
    return onDelete();
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

class _Storage implements SecureStorageService {
  int deleteAllCalls = 0;
  @override
  Future<void> deleteAll() async => deleteAllCalls++;
  @override
  Future<bool> getSoundEnabled() async => true;
  @override
  Future<bool> getBinauralEnabled() async => true;
  @override
  Future<bool> getReportNotification() async => true;
  @override
  Future<String?> getReminderTime() async => null;
  @override
  Future<String?> getThemeMode() async => null;
  @override
  Future<String?> getLocale() async => 'ja';
  @override
  Future<bool> getPauseMode() async => false;
  @override
  Future<bool> getOnboardingComplete() async => false;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Sound implements SoundManager {
  @override
  bool enabled = true;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Notifications implements NotificationService {
  int cancelAllCalls = 0;
  @override
  Future<void> cancelAll() async => cancelAllCalls++;
  @override
  Future<void> cancelDailyReminder() async {}
  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {}
  @override
  Future<void> cancelWeeklyReport() async {}
  @override
  Future<void> scheduleWeeklyReport({
    required String title,
    required String body,
  }) async {}
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

/// LocalDb whose clearAll fails (e.g. a corrupt box).
class _ThrowingLocalDb extends LocalDb {
  @override
  Future<void> clearAll() async => throw StateError('recordings box broken');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final zone = tz.getLocation('Asia/Tokyo');

  late Directory tmp;
  late Directory docs;
  late Directory cache;
  final localDb = LocalDb();
  final releaseDb = ReleaseDb();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('account_deletion_test');
    Hive.init('${tmp.path}/hive');
    await localDb.init();
    await releaseDb.init();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  late VoiceClipService clips;

  setUp(() async {
    // Seed data everywhere the deletion has to reach.
    await localDb.recordings.put('r1', {'id': 'r1'});
    await releaseDb.sessions.put('s1', {'id': 's1'});
    await releaseDb.turns.put('t1', {'id': 't1'});
    await releaseDb.pending.put('p1', {'id': 'p1'});
    await releaseDb.settings.put(ReleaseDb.settingsKey, {'x': 1});
    docs = await Directory('${tmp.path}/docs').create(recursive: true);
    cache = await Directory('${tmp.path}/cache').create(recursive: true);
    clips = VoiceClipService(
      documentsDirectory: () async => docs,
      temporaryDirectory: () async => cache,
    );
    await File('${cache.path}/${VoiceClipService.collageFileName}')
        .writeAsBytes([9]);
    await File(await clips.clipPathFor('r1')).writeAsBytes([1, 2, 3]);
  });

  ({
    ProviderContainer c,
    _FakeAuth auth,
    _Storage storage,
    _Notifications notifications,
    FakeSink sink,
  }) setup(Future<void> Function() onDelete, {LocalDb? db}) {
    final auth = _FakeAuth(onDelete);
    final storage = _Storage();
    final notifications = _Notifications();
    final sink = FakeSink();
    final c = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(auth),
      authStateProvider.overrideWith((ref) => const Stream<User?>.empty()),
      localDbProvider.overrideWithValue(db ?? localDb),
      secureStorageProvider.overrideWithValue(storage),
      voiceClipServiceProvider.overrideWithValue(clips),
      soundManagerProvider.overrideWithValue(_Sound()),
      notificationServiceProvider.overrideWithValue(notifications),
      releaseDbProvider.overrideWithValue(releaseDb),
      contentAssetLoaderProvider.overrideWithValue(const FileContentLoader()),
      releaseContentLangProvider.overrideWithValue(AppLang.ja),
      releaseNotificationSinkProvider.overrideWithValue(sink),
      releaseNotificationZoneProvider.overrideWith((ref) => zone),
      releaseTimeZoneResolverProvider.overrideWithValue(() async => zone),
    ]);
    addTearDown(c.dispose);
    return (
      c: c,
      auth: auth,
      storage: storage,
      notifications: notifications,
      sink: sink,
    );
  }

  Future<bool> clipDirExists() =>
      Directory('${docs.path}/voice_clips').exists();

  /// Everything except the recordings box (checked separately).
  Future<void> expectOtherLocalDataDeleted(
    ({
      ProviderContainer c,
      _FakeAuth auth,
      _Storage storage,
      _Notifications notifications,
      FakeSink sink,
    }) t,
  ) async {
    expect(t.storage.deleteAllCalls, 1);
    expect(await clipDirExists(), isFalse);
    expect(
      await File('${cache.path}/${VoiceClipService.collageFileName}').exists(),
      isFalse,
    );
    expect(releaseDb.sessions.isEmpty, isTrue);
    expect(releaseDb.turns.isEmpty, isTrue);
    expect(releaseDb.pending.isEmpty, isTrue);
    expect(releaseDb.settings.isEmpty, isTrue);
    expect(t.notifications.cancelAllCalls, 1);
    expect(t.sink.cancelled, containsAll(ReleaseNotificationScheduler.allIds));
  }

  test('the default cloud timeout is 10 seconds', () {
    expect(SettingsNotifier.cloudDeleteTimeout, const Duration(seconds: 10));
    expect(
      SettingsNotifier.cloudSignOutTimeout,
      lessThanOrEqualTo(const Duration(seconds: 5)),
    );
  });

  test('Firebase delete hangs → device data deleted, signed out, cloud failed',
      () async {
    final t = setup(() => Completer<void>().future); // never completes
    expect(await clipDirExists(), isTrue);

    final watch = Stopwatch()..start();
    final result = await t.c
        .read(settingsProvider.notifier)
        .deleteAccountData(cloudTimeout: const Duration(milliseconds: 200))
        .timeout(const Duration(seconds: 5));
    watch.stop();

    expect(result.cloudDeleted, isFalse);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    expect(localDb.recordings.isEmpty, isTrue);
    await expectOtherLocalDataDeleted(t);
    expect(t.auth.deleteCalls, 1);
    expect(t.auth.signOutCalls, 1);
  });

  test('Firebase delete throws → device data deleted, signed out, cloud failed',
      () async {
    final t = setup(() async => throw FirebaseAuthException(
          code: 'requires-recent-login',
        ));

    final result =
        await t.c.read(settingsProvider.notifier).deleteAccountData();

    expect(result.cloudDeleted, isFalse);
    expect(localDb.recordings.isEmpty, isTrue);
    await expectOtherLocalDataDeleted(t);
    expect(t.auth.deleteCalls, 1);
    expect(t.auth.signOutCalls, 1);
  });

  test('Firebase delete succeeds → device data deleted, cloudDeleted true',
      () async {
    final t = setup(() async {});

    final result =
        await t.c.read(settingsProvider.notifier).deleteAccountData();

    expect(result.cloudDeleted, isTrue);
    expect(localDb.recordings.isEmpty, isTrue);
    await expectOtherLocalDataDeleted(t);
    expect(t.auth.deleteCalls, 1);
    expect(t.auth.signOutCalls, 0);
  });

  test('a local step throws → other steps still run, cloud attempted, rethrown',
      () async {
    final t = setup(() async {}, db: _ThrowingLocalDb());

    await expectLater(
      t.c.read(settingsProvider.notifier).deleteAccountData(),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        'recordings box broken',
      )),
    );

    await expectOtherLocalDataDeleted(t);
    expect(t.auth.deleteCalls, 1);
    expect(t.auth.signOutCalls, 0);
  });
}
