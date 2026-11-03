import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';
import 'package:zero_app/features/release/domain/voice_tendency.dart';

const base = VoiceMetrics(energy: 0.5, clarity: 0.6, expressionRange: 0.5, tempo: 3.0);
const baseline = [base, base, base, base];

void main() {
  group('VoiceTendency', () {
    test('no tags without enough baseline recordings', () {
      const low = VoiceMetrics(energy: 0.1, clarity: 0.6, expressionRange: 0.5, tempo: 3.0);
      expect(VoiceTendency.tagsFor(low, const [base, base]), isEmpty);
    });

    test('low energy', () {
      const low = VoiceMetrics(energy: 0.3, clarity: 0.6, expressionRange: 0.5, tempo: 3.0);
      expect(VoiceTendency.tagsFor(low, baseline), [VoiceTendency.lowEnergy]);
    });

    test('fast tempo', () {
      const fast = VoiceMetrics(energy: 0.5, clarity: 0.6, expressionRange: 0.5, tempo: 4.0);
      expect(VoiceTendency.tagsFor(fast, baseline), [VoiceTendency.fastTempo]);
    });

    test('narrow range and low clarity', () {
      const v = VoiceMetrics(energy: 0.5, clarity: 0.45, expressionRange: 0.3, tempo: 3.0);
      // range: 0.2/0.5 = 40%、clarity: 0.15/0.6 = 25% → 大きい順
      expect(VoiceTendency.tagsFor(v, baseline), [VoiceTendency.narrowRange, VoiceTendency.lowClarity]);
    });

    test('at most two tags, biggest differences first', () {
      const v = VoiceMetrics(energy: 0.2, clarity: 0.3, expressionRange: 0.4, tempo: 4.5);
      final tags = VoiceTendency.tagsFor(v, baseline);
      expect(tags.length, 2);
      // energy 60%、tempo 50%、clarity 50%、range 20%
      expect(tags.first, VoiceTendency.lowEnergy);
      expect(VoiceTendency.tagsFor(v, baseline, maxTags: 1), [VoiceTendency.lowEnergy]);
    });

    test('small differences are ignored (absolute and relative thresholds)', () {
      const v = VoiceMetrics(energy: 0.45, clarity: 0.55, expressionRange: 0.46, tempo: 3.3);
      expect(VoiceTendency.tagsFor(v, baseline), isEmpty);
    });

    test('steady when every metric is within 6% of the baseline', () {
      const v = VoiceMetrics(energy: 0.51, clarity: 0.59, expressionRange: 0.49, tempo: 3.05);
      expect(VoiceTendency.tagsFor(v, baseline), [VoiceTendency.steady]);
    });

    test('null metrics are skipped', () {
      const v = VoiceMetrics(energy: 0.3);
      const nullBase = VoiceMetrics(energy: 0.5);
      expect(VoiceTendency.tagsFor(v, const [nullBase, nullBase, nullBase]), [VoiceTendency.lowEnergy]);
      expect(VoiceTendency.tagsFor(const VoiceMetrics(), baseline), isEmpty);
    });

    test('tagsForRecording uses only earlier recordings and excludes itself', () {
      RecordingModel rec(String id, int day, double energy) => RecordingModel(
            id: id,
            recordedAt: DateTime(2026, 11, day, 8),
            durationSeconds: 30,
            energy: energy,
            clarity: 0.6,
            expressionRange: 0.5,
            tempo: 3.0,
          );
      final current = rec('now', 10, 0.3);
      final previous = [
        rec('a', 1, 0.5),
        rec('b', 2, 0.5),
        rec('c', 3, 0.5),
        current,
        rec('future', 11, 0.0),
      ];
      expect(VoiceTendency.tagsForRecording(current, previous), [VoiceTendency.lowEnergy]);
      // 前の録音が 2 件しか無ければ出さない
      expect(VoiceTendency.tagsForRecording(current, previous.sublist(1)), isEmpty);
    });
  });
}
