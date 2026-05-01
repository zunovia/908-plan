import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/home/providers/home_provider.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';

RecordingModel _recording(DateTime date) => RecordingModel(
      id: date.toIso8601String(),
      recordedAt: date,
      durationSeconds: 30,
    );

void main() {
  group('computeStreak', () {
    test('returns 0 for empty list', () {
      expect(computeStreak([]), 0);
    });

    test('returns 1 for single recording today', () {
      final today = DateTime.now();
      expect(computeStreak([_recording(today)]), 1);
    });

    test('returns 1 for single recording yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(computeStreak([_recording(yesterday)]), 1);
    });

    test('returns 0 if most recent recording is 2+ days ago', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      expect(computeStreak([_recording(twoDaysAgo)]), 0);
    });

    test('counts consecutive days', () {
      final now = DateTime.now();
      final recordings = [
        _recording(now),
        _recording(now.subtract(const Duration(days: 1))),
        _recording(now.subtract(const Duration(days: 2))),
      ];
      expect(computeStreak(recordings), 3);
    });

    test('stops at gap', () {
      final now = DateTime.now();
      final recordings = [
        _recording(now),
        _recording(now.subtract(const Duration(days: 1))),
        // gap: day 2 missing
        _recording(now.subtract(const Duration(days: 3))),
      ];
      expect(computeStreak(recordings), 2);
    });

    test('deduplicates multiple recordings on same day', () {
      final now = DateTime.now();
      final recordings = [
        _recording(now),
        _recording(now.subtract(const Duration(hours: 2))),
        _recording(now.subtract(const Duration(days: 1))),
      ];
      expect(computeStreak(recordings), 2);
    });

    test('works with unordered input', () {
      final now = DateTime.now();
      final recordings = [
        _recording(now.subtract(const Duration(days: 2))),
        _recording(now),
        _recording(now.subtract(const Duration(days: 1))),
      ];
      expect(computeStreak(recordings), 3);
    });
  });
}
