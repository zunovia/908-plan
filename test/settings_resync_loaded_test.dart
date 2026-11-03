import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/core/audio/sound_manager.dart';
import 'package:zero_app/core/notifications/notification_service.dart';
import 'package:zero_app/core/providers/audio_providers.dart';
import 'package:zero_app/core/providers/auth_provider.dart';
import 'package:zero_app/core/providers/notification_providers.dart';
import 'package:zero_app/core/providers/storage_providers.dart';
import 'package:zero_app/core/storage/secure_storage.dart';
import 'package:zero_app/features/settings/providers/settings_provider.dart';

class _Storage implements SecureStorageService {
  /// While set, reading the reminder time waits (simulates a slow reload).
  Completer<void>? gate;
  @override
  Future<bool> getSoundEnabled() async => true;
  @override
  Future<bool> getBinauralEnabled() async => true;
  @override
  Future<bool> getReportNotification() async => true;
  @override
  Future<String?> getReminderTime() async {
    await gate?.future;
    return '21:00';
  }
  @override
  Future<String?> getThemeMode() async => null;
  @override
  Future<String?> getLocale() async => 'ja';
  @override
  Future<bool> getPauseMode() async => false;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Sound implements SoundManager {
  @override
  bool enabled = true;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Service implements NotificationService {
  int cancelDaily = 0;
  int scheduleDaily = 0;
  @override
  Future<void> cancelDailyReminder() async => cancelDaily++;
  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async => scheduleDaily++;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resync never runs with default settings, also after an auth change', () async {
    final service = _Service();
    final storage = _Storage();
    final authCtl = StreamController<User?>();
    addTearDown(authCtl.close);
    final c = ProviderContainer(overrides: [
      secureStorageProvider.overrideWithValue(storage),
      soundManagerProvider.overrideWithValue(_Sound()),
      notificationServiceProvider.overrideWithValue(service),
      authStateProvider.overrideWith((ref) => authCtl.stream),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(settingsProvider, (_, __) {});
    addTearDown(sub.close);
    final notifier = c.read(settingsProvider.notifier);

    // Before the first load finished: no-op (would cancel the reminder).
    await notifier.resyncNotifications();
    expect(service.cancelDaily, 0);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c.read(settingsProvider).reminderTime, '21:00');
    expect(service.scheduleDaily, 1);

    // build() re-runs (auth change) -> defaults again until reloaded.
    storage.gate = Completer<void>();
    authCtl.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(settingsProvider).reminderTime, isNull);
    await notifier.resyncNotifications();
    expect(service.cancelDaily, 0);

    storage.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(c.read(settingsProvider).reminderTime, '21:00');
    await notifier.resyncNotifications();
    expect(service.cancelDaily, 0);
    expect(service.scheduleDaily, greaterThanOrEqualTo(2));
  });
}
