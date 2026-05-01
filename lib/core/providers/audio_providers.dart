import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/recorder_service.dart';
import '../audio/sound_manager.dart';

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

final soundManagerProvider = Provider<SoundManager>((ref) {
  final manager = SoundManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});
