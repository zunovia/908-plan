import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// True after [RecordingNotifier.cancelRecording]: the take was discarded
  /// (nothing analyzed or saved), so it must not be treated as finished.
  final bool cancelled;

  /// True from the moment [RecordingNotifier.stopRecording] starts (完了 or
  /// auto-stop) until it has saved or failed. While set, the screen no longer
  /// offers cancel, so a take cannot be saved behind a "cancelled" screen.
  final bool isStopping;

  const RecordingState({
    this.isRecording = false,
    this.elapsed = Duration.zero,
    this.totalDuration = const Duration(seconds: 30),
    this.currentAmplitude = 0.0,
    this.filePath,
    this.lastRecordingId,
    this.cancelled = false,
    this.isStopping = false,
  });

  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return (elapsed.inMilliseconds / totalDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  /// A take that ended normally and was saved (what the screen moves on for).
  bool get isFinished => !isRecording && !cancelled && filePath != null;

  RecordingState copyWith({
    bool? isRecording,
    Duration? elapsed,
    Duration? totalDuration,
    double? currentAmplitude,
    String? filePath,
    String? lastRecordingId,
    bool? cancelled,
    bool? isStopping,
  }) {
    return RecordingState(
      isRecording: isRecording ?? this.isRecording,
      elapsed: elapsed ?? this.elapsed,
      totalDuration: totalDuration ?? this.totalDuration,
      currentAmplitude: currentAmplitude ?? this.currentAmplitude,
      filePath: filePath ?? this.filePath,
      lastRecordingId: lastRecordingId ?? this.lastRecordingId,
      cancelled: cancelled ?? this.cancelled,
      isStopping: isStopping ?? this.isStopping,
    );
  }
}

class RecordingNotifier extends Notifier<RecordingState> {
  Timer? _elapsedTimer;

  /// Bumped by every start and every cancel. Async work of an older take
  /// checks it after each await and gives up (discarding its file) when it
  /// has changed.
  int _session = 0;

  /// The temp WAV of the current take, so a cancel can delete it even when
  /// the recorder does not report the path.
  String? _currentPath;

  RecorderService get _recorder => ref.read(recorderServiceProvider);

  @override
  RecordingState build() {
    ref.onDispose(_cleanup);
    return const RecordingState();
  }

  Future<void> startRecording({
    Duration duration = const Duration(seconds: 30),
  }) async {
    final session = ++_session;
    state = RecordingState(
      isRecording: true,
      totalDuration: duration,
    );

    final String path;
    try {
      final tempDir = await ref.read(recordingTempDirectoryProvider)();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      path = '${tempDir.path}/zero_recording_$timestamp.wav';
    } catch (_) {
      if (session == _session) state = const RecordingState();
      return;
    }
    // Cancelled before the recorder was even started.
    if (session != _session) return;
    _currentPath = path;

    try {
      await _recorder.start(
        path: path,
        amplitudeInterval: const Duration(milliseconds: 100),
        onAmplitude: (amplitude) {
          if (session != _session) return;
          final normalized = ((amplitude.current + 60) / 60).clamp(0.0, 1.0);
          state = state.copyWith(currentAmplitude: normalized);
        },
      );
    } catch (_) {
      // Recorder failed (e.g. permission revoked) — reset to idle
      if (session == _session) {
        _currentPath = null;
        state = const RecordingState();
      }
      return;
    }

    // Cancelled while the recorder was starting: stop it and discard.
    if (session != _session) {
      await _stopAndDiscard(path);
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
    // Already stopping (e.g. 完了 right at the auto-stop): save only once.
    if (!state.isRecording || state.isStopping) return;
    final session = _session;
    // Synchronously, so the UI disables cancel before the first await.
    state = state.copyWith(isStopping: true);
    try {
      await _stopAndSave(session);
    } finally {
      // Failure paths: allow the UI to react again. (A cancel or a new take
      // has already replaced the state.)
      if (session == _session && state.isStopping) {
        state = state.copyWith(isStopping: false);
      }
    }
  }

  Future<void> _stopAndSave(int session) async {

    _elapsedTimer?.cancel();
    _elapsedTimer = null;

    final elapsed = state.elapsed;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      // Recorder stop failed — just mark as not recording
    }
    // A cancel arrived while the recorder was stopping: keep nothing.
    if (session != _session) {
      await _deleteFile(path);
      return;
    }

    if (path == null) {
      state = state.copyWith(isRecording: false, isStopping: false);
      return;
    }

    final recordingId =
        '${DateTime.now().millisecondsSinceEpoch}';

    VoiceMetrics metrics;
    try {
      metrics = await ref.read(voiceAnalyzerProvider)(path);
    } catch (_) {
      metrics = VoiceMetrics.fallback;
    }
    // A cancel arrived during the analysis: keep nothing.
    if (session != _session) {
      await _deleteFile(path);
      return;
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

    // From here on the take is kept: a later cancel only leaves the screen.
    final repo = ref.read(localRecordingRepositoryProvider);
    await repo.saveRecording(recording);

    // Keep the first seconds on-device for the weekly voice collage.
    try {
      await ref.read(voiceClipServiceProvider).saveClip(
            sourceWavPath: path,
            recordingId: recordingId,
          );
    } catch (_) {
      // Non-fatal: the collage simply skips this day.
    }

    // Delete WAV file after analysis — metrics are saved in Hive
    await _deleteFile(path);
    if (_currentPath == path) _currentPath = null;

    if (session != _session) return;
    state = state.copyWith(
      isRecording: false,
      isStopping: false,
      filePath: path,
      lastRecordingId: recordingId,
    );
  }

  /// Discards the current take: stops the recorder and deletes the temp WAV
  /// without analyzing it, saving a record or keeping a voice clip.
  ///
  /// The state is reset synchronously (before any await) and marked
  /// [RecordingState.cancelled], so a screen listening for "recording
  /// finished" never moves on to the result.
  Future<void> cancelRecording() async {
    _session++;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    final wasRecording = state.isRecording;
    final path = _currentPath;
    _currentPath = null;
    state = RecordingState(
      totalDuration: state.totalDuration,
      cancelled: true,
    );
    if (!wasRecording) {
      await _deleteFile(path);
      return;
    }
    await _stopAndDiscard(path);
  }

  Future<void> _stopAndDiscard(String? knownPath) async {
    String? stoppedPath;
    try {
      stoppedPath = await _recorder.stop();
    } catch (_) {
      // Already stopped or never started: nothing to stop.
    }
    await _deleteFile(stoppedPath);
    if (knownPath != stoppedPath) await _deleteFile(knownPath);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Non-fatal: OS will eventually reclaim temp directory
    }
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
