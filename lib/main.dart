import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/audio/sound_manager.dart';
import 'core/audio/voice_clip_service.dart';
import 'core/notifications/notification_route.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/release_notification_sync.dart';
import 'core/providers/audio_providers.dart';
import 'core/providers/notification_providers.dart';
import 'core/providers/storage_providers.dart';
import 'core/storage/local_db.dart';
import 'core/storage/secure_storage.dart';
import 'features/release/data/release_db.dart';
import 'features/release/providers/release_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase unavailable — auth features will be disabled.
  }

  await Hive.initFlutter();

  final localDb = LocalDb();
  await localDb.init();

  // 手放す (release) storage. A failure here must never block app start
  // (the release tab then shows its error state; recordings keep working).
  final releaseDb = ReleaseDb();
  try {
    await releaseDb.init();
  } catch (_) {}

  // Read sound preference before any screen renders to prevent
  // splash sounds from playing when user has disabled them.
  final secureStorage = SecureStorageService();
  final soundEnabled = await secureStorage.getSoundEnabled();
  final soundManager = SoundManager()..enabled = soundEnabled;

  // Local notifications (daily reminder / weekly report). Failure here must
  // never block app start.
  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (_) {}

  // Drop voice clips older than the retention window (fire-and-forget).
  final voiceClipService = VoiceClipService();
  unawaited(voiceClipService.prune().catchError((_) => 0));

  final container = ProviderContainer(
    overrides: [
      localDbProvider.overrideWithValue(localDb),
      secureStorageProvider.overrideWithValue(secureStorage),
      soundManagerProvider.overrideWithValue(soundManager),
      notificationServiceProvider.overrideWithValue(notificationService),
      voiceClipServiceProvider.overrideWithValue(voiceClipService),
      releaseDbProvider.overrideWithValue(releaseDb),
    ],
  );

  // A tapped release notification opens its route (app.dart navigates).
  final routeDeduper = NotificationRouteDeduper();
  void openRoute(String route) {
    if (!routeDeduper.accept(route)) return;
    container.read(notificationRouteProvider.notifier).state = route;
  }

  notificationService.onRoute = openRoute;

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZeroApp(),
    ),
  );

  // After the first frame so the router listener is already in place.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      try {
        final route = await notificationService.launchRoute();
        if (route != null) openRoute(route);
      } catch (_) {}
    }());
  });

  // Release notifications: rebuild the schedule now and whenever the app
  // returns to the foreground. Best-effort; never blocks start-up.
  try {
    final releaseSync = container.read(releaseNotificationSyncProvider);
    releaseSync.attachLifecycle();
    unawaited(releaseSync.resync());
  } catch (_) {}
}
