import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/core/insights/agreement_engine.dart';
import 'package:zero_app/features/recording/data/recording_model.dart';

RecordingModel _rec(
  DateTime at, {
  double energy = 0.5,
  double expression = 0.2,
  double tempo = 3.0,
  String? self,
}) {
  return RecordingModel(
    id: at.millisecondsSinceEpoch.toString(),
    recordedAt: at,
    durationSeconds: 30,
    energy: energy,
    clarity: 0.5,
    expressionRange: expression,
    tempo: tempo,
    selfAssessment: self,
  );
}

void main() {
  final now = DateTime(2026, 10, 13, 12);

  group('AgreementEngine.estimate', () {
    test('low expression, mid tempo and energy → calm', () {
      expect(AgreementEngine.estimate(_rec(now, expression: 0.1)), 'calm');
    });

    test('high expression and fast tempo → shaky', () {
      expect(
        AgreementEngine.estimate(_rec(now, expression: 0.9, tempo: 6.0)),
        'shaky',
      );
    });

    test('moderate values → normal', () {
      expect(
        AgreementEngine.estimate(_rec(now, expression: 0.5, tempo: 3.8)),
        'normal',
      );
    });

    test('turbulence and estimate are null when a metric is missing', () {
      final r = RecordingModel(
        id: 'x',
        recordedAt: now,
        durationSeconds: 30,
        energy: 0.5,
      );
      expect(AgreementEngine.turbulence(r), isNull);
      expect(AgreementEngine.estimate(r), isNull);
    });

    test('turbulence stays within 0..1', () {
      final r = _rec(now, energy: 1.0, expression: 1.0, tempo: 8.0);
      expect(AgreementEngine.turbulence(r), inInclusiveRange(0.0, 1.0));
    });
  });

  group('AgreementEngine.compute', () {
    test('counts matches only for usable self-assessments in the window', () {
      final recs = [
        _rec(now.subtract(const Duration(days: 1)),
            expression: 0.1, self: 'calm'),
        _rec(now.subtract(const Duration(days: 2)),
            expression: 0.1, self: 'shaky'),
        _rec(now.subtract(const Duration(days: 3)),
            expression: 0.9, tempo: 6, self: 'shaky'),
        _rec(now.subtract(const Duration(days: 4)),
            expression: 0.1, self: 'unknown'),
        _rec(now.subtract(const Duration(days: 5)), expression: 0.1),
        // 20 days ago → previous window
        _rec(now.subtract(const Duration(days: 20)),
            expression: 0.1, self: 'calm'),
      ];
      final result = AgreementEngine.compute(recs, now: now);
      expect(result.total, 3);
      expect(result.matched, 2);
      expect(result.rate, closeTo(2 / 3, 1e-9));
      expect(result.hasEnoughData, isTrue);
      // previous window has only one sample → no previous rate
      expect(result.previousRate, isNull);
      expect(result.isRising, isFalse);
    });

    test('detects a rising rate against the previous window', () {
      final recs = <RecordingModel>[];
      // previous window: 3 samples, 0 matches
      for (var d = 15; d <= 17; d++) {
        recs.add(_rec(now.subtract(Duration(days: d)),
            expression: 0.1, self: 'shaky'));
      }
      // current window: 3 samples, 3 matches
      for (var d = 1; d <= 3; d++) {
        recs.add(_rec(now.subtract(Duration(days: d)),
            expression: 0.1, self: 'calm'));
      }
      final result = AgreementEngine.compute(recs, now: now);
      expect(result.previousRate, 0.0);
      expect(result.rate, 1.0);
      expect(result.isRising, isTrue);
    });

    test('is not rising with too few current samples', () {
      final recs = <RecordingModel>[];
      for (var d = 15; d <= 17; d++) {
        recs.add(_rec(now.subtract(Duration(days: d)),
            expression: 0.1, self: 'shaky'));
      }
      recs.add(_rec(now.subtract(const Duration(days: 1)),
          expression: 0.1, self: 'calm'));
      final result = AgreementEngine.compute(recs, now: now);
      expect(result.total, 1);
      expect(result.isRising, isFalse);
    });

    test('empty input yields empty result', () {
      final result = AgreementEngine.compute(const [], now: now);
      expect(result.total, 0);
      expect(result.rate, isNull);
      expect(result.hasEnoughData, isFalse);
      expect(result.isRising, isFalse);
    });
  });
}
