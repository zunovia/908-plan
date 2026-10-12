import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/audio/sound_manager.dart';
import 'core/audio/voice_clip_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/audio_providers.dart';
import 'core/providers/notification_providers.dart';
import 'core/providers/storage_providers.dart';
import 'core/storage/local_db.dart';
import 'core/storage/secure_storage.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(localDb),
        secureStorageProvider.overrideWithValue(secureStorage),
        soundManagerProvider.overrideWithValue(soundManager),
        notificationServiceProvider.overrideWithValue(notificationService),
        voiceClipServiceProvider.overrideWithValue(voiceClipService),
      ],
      child: const ZeroApp(),
    ),
  );
}
