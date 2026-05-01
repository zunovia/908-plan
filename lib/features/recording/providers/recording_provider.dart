import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/audio/recorder_service.dart';
import '../../../core/audio/voice_analyzer.dart';
import '../../../core/providers/audio_providers.dart';
import '../../../core/providers/storage_providers.dart';
import '../data/recording_model.dart';

class RecordingState {
  final bool isRecording;
  final Duration elapsed;
  final Duration totalDuration;
  final double currentAmplitude;
  final String? filePath;
  final String? lastRecordingId;

  const RecordingState({
    this.isRecording = false,
    this.elapsed = Duration.zero,
    this.totalDuration = const Duration(seconds: 30),
    this.currentAmplitude = 0.0,
    this.filePath,
    this.lastRecordingId,
  });

  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return (elapsed.inMilliseconds / totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  RecordingState copyWith({
    bool? isRecording,
    Duration? elapsed,
    Duration? totalDuration,
    double? currentAmplitude,
    String? filePath,
    String? lastRecordingId,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      elapsed: elapsed ?? this.elapsed,
      totalDuration: totalDuration ?? this.totalDuration,
      currentAmplitude: currentAmplitude ?? this.currentAmplitude,
      filePath: filePath ?? this.filePath,
      lastRecordingId: lastRecordingId ?? this.lastRecordingId,
    );
  }
}

class RecordingNotifier extends Notifier<RecordingState> {
  Timer? _elapsedTimer;
  RecorderService get _recorder => ref.read(recorderServiceProvider);

  @override
  RecordingState build() {
    ref.onDispose(_cleanup);
    return const RecordingState();
  }

  Future<void> startRecording({
    Duration duration = const Duration(seconds: 30),
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/zero_recording_$timestamp.wav';

    state = RecordingState(
      isRecording: true,
      totalDuration: duration,
    );

    try {
      await _recorder.start(
        path: path,
        amplitudeInterval: const Duration(milliseconds: 100),
        onAmplitude: (amplitude) {
          final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
          state = state.copyWith(currentAmplitude: normalized);
        },
      );
    } catch (_) {
      // Recorder failed (e.g. permission revoked) — reset to idle
      state = const RecordingState();
      return;
    }

    _elapsedTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        final newElapsed = state.elapsed + const Duration(milliseconds: 100);
        if (newElapsed >= state.totalDuration) {
          stopRecording();
          return;
        }
        state = state.copyWith(elapsed: newElapsed);
      },
    );
  }

  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    final elapsed = state.elapsed;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      // Recorder stop failed — just mark as not recording
    }

    if (path == null) {
      state = state.copyWith(isRecording: false);
      return;
    }

    final recordingId =
        '${DateTime.now().millisecondsSinceEpoch}';

    VoiceMetrics metrics;
    try {
      metrics = await VoiceAnalyzer.analyze(path);
    } catch (_) {
      metrics = VoiceMetrics.fallback;
    }

    final recording = RecordingModel(
      id: recordingId,
      recordedAt: DateTime.now(),
      durationSeconds: elapsed.inSeconds,
      energy: metrics.energy,
      clarity: metrics.clarity,
      expressionRange: metrics.expressionRange,
      tempo: metrics.tempo,
    );

    final repo = ref.read(localRecordingRepositoryProvider);
    await repo.saveRecording(recording);

    state = state.copyWith(
      isRecording: false,
      filePath: path,
      lastRecordingId: recordingId,
    );
  }

  Future<void> saveSelfAssessment(String assessment) async {
    final recordingId = state.lastRecordingId;
    if (recordingId == null) return;

    final repo = ref.read(localRecordingRepositoryProvider);
    final recordings = repo.getRecordings();
    final recording = recordings.where((r) => r.id == recordingId).firstOrNull;
    if (recording == null) return;

    final updated = RecordingModel(
      id: recording.id,
      recordedAt: recording.recordedAt,
      durationSeconds: recording.durationSeconds,
      energy: recording.energy,
      clarity: recording.clarity,
      expressionRange: recording.expressionRange,
      tempo: recording.tempo,
      selfAssessment: assessment,
    );
    await repo.saveRecording(updated);
  }

  void _cleanup() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }
}

final recordingProvider =
    NotifierProvider<RecordingNotifier, RecordingState>(
  RecordingNotifier.new,
);
