import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/recorder_service.dart';
import '../audio/sound_manager.dart';
import '../audio/voice_analyzer.dart';
import '../audio/voice_clip_service.dart';

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

final voiceClipServiceProvider = Provider<VoiceClipService>((ref) {
  return VoiceClipService();
});

/// Analyzes a finished recording (overridable in tests).
final voiceAnalyzerProvider =
    Provider<Future<VoiceMetrics> Function(String path)>((ref) {
  return VoiceAnalyzer.analyze;
});

/// Where the in-progress WAV is written (overridable in tests).
final recordingTempDirectoryProvider =
    Provider<Future<Directory> Function()>((ref) {
  return getTemporaryDirectory;
});

final soundManagerProvider = Provider<SoundManager>((ref) {
  final manager = SoundManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});
