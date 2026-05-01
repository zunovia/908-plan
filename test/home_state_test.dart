import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/home/presentation/widgets/duration_selector.dart';
import 'package:zero_app/features/home/providers/home_provider.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';

void main() {
  group('HomeState', () {
    test('default values', () {
      const state = HomeState();
      expect(state.dayCount, 0);
      expect(state.streak, 0);
      expect(state.dailyPrompt, '');
      expect(state.recentRecordings, isEmpty);
      expect(state.hasEnoughData, isFalse);
    });

    test('copyWith preserves all fields when no args given', () {
      final recordings = [
        RecordingModel(
          id: 'r1',
          recordedAt: DateTime(2025, 5, 1),
          durationSeconds: 30,
        ),
      ];
      final state = HomeState(
        dayCount: 10,
        streak: 3,
        dailyPrompt: 'テスト',
        selectedDuration: RecordingDuration.short15,
        recentRecordings: recordings,
        hasEnoughData: true,
      );

      final copied = state.copyWith();

      expect(copied.dayCount, 10);
      expect(copied.streak, 3);
      expect(copied.dailyPrompt, 'テスト');
      expect(copied.selectedDuration, RecordingDuration.short15);
      expect(copied.recentRecordings, recordings);
      expect(copied.hasEnoughData, isTrue);
    });

    test('copyWith overrides specific fields', () {
      const state = HomeState(dayCount: 5, streak: 2);
      final updated = state.copyWith(dayCount: 10, hasEnoughData: true);

      expect(updated.dayCount, 10);
      expect(updated.hasEnoughData, isTrue);
      // Unchanged
      expect(updated.streak, 2);
      expect(updated.dailyPrompt, '');
      expect(updated.selectedDuration, RecordingDuration.normal30);
    });
  });
}
