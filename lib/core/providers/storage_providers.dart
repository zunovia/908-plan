import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recording/data/local_recording_repository.dart';
import '../storage/local_db.dart';
import '../storage/secure_storage.dart';

/// Must be overridden in main() after LocalDb.init() completes.
final localDbProvider = Provider<LocalDb>((ref) {
  throw StateError(
    'localDbProvider must be overridden in main() after LocalDb.init()',
  );
});

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final localRecordingRepositoryProvider =
    Provider<LocalRecordingRepository>((ref) {
  return LocalRecordingRepository(ref.watch(localDbProvider));
});
