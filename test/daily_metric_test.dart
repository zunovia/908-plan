import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/reports/data/report_model.dart';

void main() {
  group('DailyMetric', () {
    test('fromJson parses correctly', () {
      final json = {
        'date': '2025-04-10T00:00:00.000',
        'energy': 0.75,
        'clarity': 0.85,
        'expression_range': 0.6,
        'tempo': 4.2,
      };

      final metric = DailyMetric.fromJson(json);

      expect(metric.date, DateTime(2025, 4, 10));
      expect(metric.energy, 0.75);
      expect(metric.clarity, 0.85);
      expect(metric.expressionRange, 0.6);
      expect(metric.tempo, 4.2);
    });

    test('toJson produces expected keys', () {
      final metric = DailyMetric(
        date: DateTime(2025, 5, 1),
        energy: 0.5,
        clarity: 0.7,
        expressionRange: 0.9,
        tempo: 3.5,
      );

      final json = metric.toJson();

      expect(json['date'], contains('2025-05-01'));
      expect(json['energy'], 0.5);
      expect(json['clarity'], 0.7);
      expect(json['expression_range'], 0.9);
      expect(json['tempo'], 3.5);
    });

    test('fromJson/toJson roundtrip', () {
      final original = DailyMetric(
        date: DateTime(2025, 3, 15),
        energy: 0.42,
        clarity: 0.88,
        expressionRange: 0.31,
        tempo: 2.8,
      );

      final restored = DailyMetric.fromJson(original.toJson());

      expect(restored.date, original.date);
      expect(restored.energy, original.energy);
      expect(restored.clarity, original.clarity);
      expect(restored.expressionRange, original.expressionRange);
      expect(restored.tempo, original.tempo);
    });

    test('fromJson handles integer values', () {
      final json = {
        'date': '2025-01-01T00:00:00.000',
        'energy': 1,
        'clarity': 0,
        'expression_range': 1,
        'tempo': 3,
      };

      final metric = DailyMetric.fromJson(json);

      expect(metric.energy, 1.0);
      expect(metric.clarity, 0.0);
      expect(metric.expressionRange, 1.0);
      expect(metric.tempo, 3.0);
    });

    test('fromJson uses default tempo when missing', () {
      final json = {
        'date': '2025-01-01T00:00:00.000',
        'energy': 0.5,
        'clarity': 0.5,
        'expression_range': 0.5,
      };

      final metric = DailyMetric.fromJson(json);

      expect(metric.tempo, 3.0);
    });
  });
}
