import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/recorder_service.dart';
import '../audio/sound_manager.dart';
import '../audio/voice_clip_service.dart';

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

final voiceClipServiceProvider = Provider<VoiceClipService>((ref) {
  return VoiceClipService();
});

final soundManagerProvider = Provider<SoundManager>((ref) {
  final manager = SoundManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});
