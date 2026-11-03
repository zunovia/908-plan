// Fakes for the recording notifier / screen tests (no platform channel,
// no Hive, no real microphone).

import 'dart:async';
import 'dart:io';

import 'package:record/record.dart';
import 'package:zero_app/core/audio/recorder_service.dart';
import 'package:zero_app/core/audio/sound_manager.dart';
import 'package:zero_app/core/audio/voice_analyzer.dart';
import 'package:zero_app/core/audio/voice_clip_service.dart';
import 'package:zero_app/features/recording/data/local_recording_repository.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';

/// Stands in for the microphone. Optionally writes a placeholder file at the
/// given path on start (like the real recorder does) so tests can check that
/// the temp WAV is deleted.
class FakeRecorderService implements RecorderService {
  FakeRecorderService({this.writeFiles = false});

  final bool writeFiles;
  final List<String> startedPaths = [];
  int stopCalls = 0;
  String? _activePath;

  /// When set, start() waits for it (to cancel while the recorder starts).
  Completer<void>? startGate;

  /// When true, stop() reports no file (recorder failure).
  bool stopReturnsNull = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start({
    required String path,
    Duration amplitudeInterval = const Duration(milliseconds: 100),
    void Function(Amplitude)? onAmplitude,
  }) async {
    startedPaths.add(path);
    if (writeFiles) {
      await File(path).writeAsBytes(List<int>.filled(64, 1));
    }
    _activePath = path;
    final gate = startGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    final path = _activePath;
    _activePath = null;
    return stopReturnsNull ? null : path;
  }

  @override
  Future<bool> isRecording() async => _activePath != null;

  @override
  Future<void> dispose() async {}
}

/// Counts analyses; [gate] lets a test hold the analysis open.
class FakeAnalyzer {
  int calls = 0;
  Completer<void>? gate;

  Future<VoiceMetrics> analyze(String path) async {
    calls++;
    final g = gate;
    if (g != null) await g.future;
    return VoiceMetrics.fallback;
  }
}

class FakeRecordingRepository implements LocalRecordingRepository {
  final List<RecordingModel> saved = [];

  @override
  Future<void> saveRecording(RecordingModel recording) async {
    saved.removeWhere((r) => r.id == recording.id);
    saved.add(recording);
  }

  @override
  List<RecordingModel> getRecordings() => List.of(saved);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeVoiceClipService implements VoiceClipService {
  final List<String> clippedIds = [];

  @override
  Future<String?> saveClip({
    required String sourceWavPath,
    required String recordingId,
  }) async {
    clippedIds.add(recordingId);
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSoundManager implements SoundManager {
  @override
  bool enabled = true;

  @override
  Future<void> play(SoundId sound, {bool loop = false}) async {}

  @override
  Future<void> stop(SoundId sound) async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
