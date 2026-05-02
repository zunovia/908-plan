import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/audio/sound_manager.dart';
import 'core/providers/audio_providers.dart';
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

  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(localDb),
        secureStorageProvider.overrideWithValue(secureStorage),
        soundManagerProvider.overrideWithValue(soundManager),
      ],
      child: const ZeroApp(),
    ),
  );
}
