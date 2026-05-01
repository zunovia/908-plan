import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_ce/hive_ce.dart';

import 'app.dart';
import 'core/providers/storage_providers.dart';
import 'core/storage/local_db.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        localDbProvider.overrideWithValue(localDb),
      ],
      child: const ZeroApp(),
    ),
  );
}
