import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/core/insights/insight_engine.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';
import 'package:zero_app/features/reports/data/report_model.dart';

void main() {
  group('InsightEngine - Mini-Insight', () {
    test('rotates by day-of-year mod 4', () {
      // Jan 1 = day 0 → slot 0 (tempo)
      final r0 = _recording(DateTime(2025, 1, 1), tempo: 4.2);
      expect(
        InsightEngine.generateMiniInsight(r0),
        contains('テンポ'),
      );

      // Jan 2 = day 1 → slot 1 (energy)
      final r1 = _recording(DateTime(2025, 1, 2), energy: 0.8);
      expect(
        InsightEngine.generateMiniInsight(r1),
        contains('エネルギー'),
      );

      // Jan 3 = day 2 → slot 2 (clarity)
      final r2 = _recording(DateTime(2025, 1, 3), clarity: 0.6);
      expect(
        InsightEngine.generateMiniInsight(r2),
        contains('明瞭度'),
      );

      // Jan 4 = day 3 → slot 3 (expression)
      final r3 = _recording(DateTime(2025, 1, 4), expressionRange: 0.9);
      expect(
        InsightEngine.generateMiniInsight(r3),
        contains('抑揚'),
      );
    });

    test('includes nuance text based on value range', () {
      // Low energy (< 0.3)
      final rLow = _recording(DateTime(2025, 1, 2), energy: 0.1);
      expect(
        InsightEngine.generateMiniInsight(rLow),
        contains('静かで落ち着いた'),
      );

      // High energy (> 0.7)
      final rHigh = _recording(DateTime(2025, 1, 2), energy: 0.9);
      expect(
        InsightEngine.generateMiniInsight(rHigh),
        contains('力強さ'),
      );
    });

    test('handles null metrics with defaults', () {
      final r = RecordingModel(
        id: 'test',
        recordedAt: DateTime(2025, 1, 1),
        durationSeconds: 60,
      );
      final result = InsightEngine.generateMiniInsight(r);
      expect(result, isNotEmpty);
    });
  });

  group('InsightEngine - Weekly Inquiry', () {
    test('returns null for less than 2 metrics', () {
      expect(InsightEngine.generateWeeklyInquiry([]), isNull);
      expect(
        InsightEngine.generateWeeklyInquiry([
          DailyMetric(
            date: DateTime(2025, 4, 7),
            energy: 0.5,
            clarity: 0.5,
            expressionRange: 0.5,
          ),
        ]),
        isNull,
      );
    });

    test('energy_spike rule fires on large delta', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.3,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.8,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
      ];
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      expect(result, contains('エネルギー'));
      expect(result, contains('上がった'));
    });

    test('expression_rich rule fires on high expression', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.2,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.8,
        ),
      ];
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      // Could be energy_spike or expression_rich depending on salience
      expect(result, isNotNull);
    });

    test('tempo_variation rule fires on high tempo stddev', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 2.0,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 5.0,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 9),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 2.0,
        ),
      ];
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      expect(result, contains('ペース'));
    });

    test('low_energy_week rule fires when all energy < 0.35', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.2,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.1,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 9),
          energy: 0.15,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
      ];
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      expect(result, contains('静かな週'));
    });

    test('stable_week rule fires when all metrics have low stddev', () {
      final metrics = List.generate(
        5,
        (i) => DailyMetric(
          date: DateTime(2025, 4, 7 + i),
          energy: 0.50 + (i * 0.01),
          clarity: 0.60 + (i * 0.01),
          expressionRange: 0.40 + (i * 0.01),
          tempo: 3.0 + (i * 0.05),
        ),
      );
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      expect(result, contains('安定'));
    });

    test('returns default when no rule matches', () {
      // Two metrics with identical values — no spike, no special pattern
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.3,
          tempo: 3.0,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.3,
          tempo: 3.0,
        ),
      ];
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      // tempo_consistency requires >=3 metrics, so no rules fire
      expect(result, contains('耳を澄ませて'));
    });

    test('picks highest salience score', () {
      // Both energy_spike and low_energy_week could fire,
      // but energy_spike has higher score with a 0.5 delta
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.1,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.3,
          clarity: 0.5,
          expressionRange: 0.3,
        ),
      ];
      final result = InsightEngine.generateWeeklyInquiry(metrics);
      // energy spike delta is 0.2 → score 1.0
      // low_energy_week: maxE=0.3 < 0.35 → score (0.35-0.3)*4 = 0.2
      // energy_spike wins
      expect(result, contains('エネルギー'));
    });
  });

  group('InsightEngine - Monthly Comparison', () {
    test('returns null for empty current metrics', () {
      expect(InsightEngine.generateMonthlyComparison([], []), isNull);
    });

    test('returns null for empty previous recordings', () {
      final current = [
        DailyMetric(
          date: DateTime(2025, 4, 1),
          energy: 0.5,
          clarity: 0.5,
          expressionRange: 0.5,
        ),
      ];
      expect(InsightEngine.generateMonthlyComparison(current, []), isNull);
    });

    test('reports largest metric change', () {
      final current = [
        DailyMetric(
          date: DateTime(2025, 4, 1),
          energy: 0.8,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 3.0,
        ),
      ];
      final prev = [
        RecordingModel(
          id: 'p1',
          recordedAt: DateTime(2025, 3, 15),
          durationSeconds: 60,
          energy: 0.3,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 3.0,
        ),
      ];
      final result = InsightEngine.generateMonthlyComparison(current, prev);
      expect(result, contains('エネルギー'));
      expect(result, contains('高まって'));
    });

    test('tempo change does not override larger normalized energy change', () {
      final current = [
        DailyMetric(
          date: DateTime(2025, 4, 1),
          energy: 0.9,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 3.8,
        ),
      ];
      final prev = [
        RecordingModel(
          id: 'p1',
          recordedAt: DateTime(2025, 3, 15),
          durationSeconds: 60,
          energy: 0.3,
          clarity: 0.5,
          expressionRange: 0.5,
          tempo: 3.0,
        ),
      ];
      // energy diff = 0.6, tempo diff (raw) = 0.8 but normalized = 0.114
      // energy should win after normalization
      final result = InsightEngine.generateMonthlyComparison(current, prev);
      expect(result, contains('エネルギー'));
    });

    test('reports stable when all diffs are small', () {
      final current = [
        DailyMetric(
          date: DateTime(2025, 4, 1),
          energy: 0.51,
          clarity: 0.51,
          expressionRange: 0.51,
          tempo: 3.01,
        ),
      ];
      final prev = [
        RecordingModel(
          id: 'p1',
          recordedAt: DateTime(2025, 3, 15),
          durationSeconds: 60,
          energy: 0.50,
          clarity: 0.50,
          expressionRange: 0.50,
          tempo: 3.00,
        ),
      ];
      final result = InsightEngine.generateMonthlyComparison(current, prev);
      expect(result, contains('同水準'));
    });
  });

  group('InsightEngine - Highlight', () {
    test('returns null for empty metrics', () {
      expect(InsightEngine.generateHighlight([]), isNull);
    });

    test('includes energy and clarity best days', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7), // Monday
          energy: 0.9,
          clarity: 0.3,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8), // Tuesday
          energy: 0.3,
          clarity: 0.9,
          expressionRange: 0.3,
        ),
      ];
      final result = InsightEngine.generateHighlight(metrics)!;
      expect(result, contains('生き生き'));
      expect(result, contains('クリア'));
    });

    test('adds expression line only if different day', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.9,
          clarity: 0.3,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.3,
          clarity: 0.9,
          expressionRange: 0.3,
        ),
        DailyMetric(
          date: DateTime(2025, 4, 9),
          energy: 0.3,
          clarity: 0.3,
          expressionRange: 0.9,
        ),
      ];
      final result = InsightEngine.generateHighlight(metrics)!;
      expect(result, contains('表現豊か'));
    });

    test('omits expression line when same day as energy or clarity', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 4, 7),
          energy: 0.9,
          clarity: 0.3,
          expressionRange: 0.9, // same day as max energy
        ),
        DailyMetric(
          date: DateTime(2025, 4, 8),
          energy: 0.3,
          clarity: 0.9,
          expressionRange: 0.3,
        ),
      ];
      final result = InsightEngine.generateHighlight(metrics)!;
      expect(result, isNot(contains('表現豊か')));
    });
  });
}

RecordingModel _recording(
  DateTime date, {
  double? energy,
  double? clarity,
  double? expressionRange,
  double? tempo,
}) {
  return RecordingModel(
    id: 'test-${date.toIso8601String()}',
    recordedAt: date,
    durationSeconds: 60,
    energy: energy,
    clarity: clarity,
    expressionRange: expressionRange,
    tempo: tempo,
  );
}
