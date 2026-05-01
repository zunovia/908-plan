import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/reports/data/report_model.dart';
import 'package:zero_app/features/reports/providers/report_provider.dart';

void main() {
  group('ReportState', () {
    test('default values', () {
      const state = ReportState();
      expect(state.dateRange, '');
      expect(state.isLoading, isFalse);
      expect(state.metrics, isEmpty);
      expect(state.highlight, isNull);
      expect(state.inquiry, isNull);
      expect(state.hasData, isFalse);
    });

    test('hasData returns true when metrics is non-empty', () {
      final state = ReportState(
        metrics: [
          DailyMetric(
            date: DateTime(2025, 5, 1),
            energy: 0.5,
            clarity: 0.5,
            expressionRange: 0.5,
          ),
        ],
      );
      expect(state.hasData, isTrue);
    });

    test('hasData returns false when metrics is empty', () {
      const state = ReportState(metrics: []);
      expect(state.hasData, isFalse);
    });

    test('copyWith preserves all fields when no args given', () {
      final metrics = [
        DailyMetric(
          date: DateTime(2025, 5, 1),
          energy: 0.7,
          clarity: 0.8,
          expressionRange: 0.6,
          tempo: 4.0,
        ),
      ];
      final state = ReportState(
        dateRange: '5/1 - 5/7',
        isLoading: false,
        metrics: metrics,
        highlight: 'ハイライト',
        inquiry: '問いかけ',
      );

      final copied = state.copyWith();

      expect(copied.dateRange, '5/1 - 5/7');
      expect(copied.isLoading, isFalse);
      expect(copied.metrics, metrics);
      expect(copied.highlight, 'ハイライト');
      expect(copied.inquiry, '問いかけ');
    });

    test('copyWith overrides specific fields', () {
      const state = ReportState(isLoading: true);
      final updated = state.copyWith(
        isLoading: false,
        dateRange: '5/1 - 5/7',
      );

      expect(updated.isLoading, isFalse);
      expect(updated.dateRange, '5/1 - 5/7');
      // Unchanged
      expect(updated.metrics, isEmpty);
      expect(updated.highlight, isNull);
    });

    test('copyWith cannot clear highlight or inquiry via null (no sentinel)', () {
      final state = ReportState(
        highlight: '既存ハイライト',
        inquiry: '既存問いかけ',
      );
      // Without sentinel, null argument falls through to ?? this.highlight
      final result = state.copyWith(highlight: null, inquiry: null);
      expect(result.highlight, '既存ハイライト');
      expect(result.inquiry, '既存問いかけ');
    });
  });
}
