import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RecordingPhase {
  recording,
  breathing,
  miniInsight,
  selfAssessment,
  quietWord,
}

class RecordingPhaseNotifier extends Notifier<RecordingPhase> {
  @override
  RecordingPhase build() {
    return RecordingPhase.recording;
  }

  void nextPhase() {
    final currentIndex = RecordingPhase.values.indexOf(state);
    if (currentIndex < RecordingPhase.values.length - 1) {
      state = RecordingPhase.values[currentIndex + 1];
    }
  }

  void reset() {
    state = RecordingPhase.recording;
  }
}

final recordingPhaseProvider =
    NotifierProvider<RecordingPhaseNotifier, RecordingPhase>(
  RecordingPhaseNotifier.new,
);
