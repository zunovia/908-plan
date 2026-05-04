import 'dart:math' as math;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../features/recording/data/recording_model.dart';
import '../../features/reports/data/report_model.dart';

/// Pure Dart rule-based insight engine.
/// Generates varied insight texts from voice metrics without LLM.
class InsightEngine {
  InsightEngine._();

  // ---------------------------------------------------------------------------
  // A. Mini-Insight (right after recording)
  // ---------------------------------------------------------------------------

  /// Returns a two-line mini-insight for the given recording.
  /// Rotates across 4 metrics based on day-of-year.
  static String generateMiniInsight(RecordingModel recording, AppLocalizations l10n) {
    final dayOfYear = _dayOfYear(recording.recordedAt);
    final slot = dayOfYear % 4;

    switch (slot) {
      case 0:
        return _miniTempo(recording.tempo ?? 3.0, l10n);
      case 1:
        return _miniEnergy(recording.energy ?? 0.5, l10n);
      case 2:
        return _miniClarity(recording.clarity ?? 0.5, l10n);
      case 3:
        return _miniExpression(recording.expressionRange ?? 0.5, l10n);
      default:
        return _miniTempo(recording.tempo ?? 3.0, l10n);
    }
  }

  static String _miniTempo(double tempo, AppLocalizations l10n) {
    final tempoStr = tempo.toStringAsFixed(1);
    final nuance = _tempoNuance(tempo, l10n);
    return l10n.insight_mini_tempo(tempoStr, nuance);
  }

  static String _miniEnergy(double energy, AppLocalizations l10n) {
    final pct = (energy * 100).round();
    final nuance = _levelNuance(energy, l10n);
    return l10n.insight_mini_energy(pct, nuance);
  }

  static String _miniClarity(double clarity, AppLocalizations l10n) {
    final pct = (clarity * 100).round();
    final nuance = _levelNuance(clarity, l10n);
    return l10n.insight_mini_clarity(pct, nuance);
  }

  static String _miniExpression(double expr, AppLocalizations l10n) {
    final pct = (expr * 100).round();
    final nuance = _levelNuance(expr, l10n);
    return l10n.insight_mini_expression(pct, nuance);
  }

  static String _levelNuance(double value, AppLocalizations l10n) {
    if (value < 0.3) return l10n.insight_nuance_quiet;
    if (value < 0.7) return l10n.insight_nuance_normal;
    return l10n.insight_nuance_strong;
  }

  static String _tempoNuance(double tempo, AppLocalizations l10n) {
    if (tempo < 2.5) return l10n.insight_tempo_slow;
    if (tempo < 4.5) return l10n.insight_tempo_normal;
    return l10n.insight_tempo_fast;
  }

  // ---------------------------------------------------------------------------
  // B. Weekly Inquiry (weekly report)
  // ---------------------------------------------------------------------------

  /// Returns the most salient inquiry question for the week's metrics.
  static String? generateWeeklyInquiry(List<DailyMetric> metrics, AppLocalizations l10n) {
    if (metrics.length < 2) return null;

    final dayFormat = DateFormat('EEEE', l10n.localeName);

    // Evaluate all rules and pick the one with the highest salience score
    final candidates = <_ScoredInquiry>[];

    // Rule 1: energy_spike
    _ruleEnergySpike(metrics, dayFormat, candidates, l10n);

    // Rule 2: expression_rich
    _ruleExpressionRich(metrics, dayFormat, candidates, l10n);

    // Rule 3: clarity_trend
    _ruleClarityTrend(metrics, candidates, l10n);

    // Rule 4: tempo_variation
    _ruleTempoVariation(metrics, candidates, l10n);

    // Rule 5: tempo_consistency
    _ruleTempoConsistency(metrics, candidates, l10n);

    // Rule 6: energy_clarity_diverge
    _ruleEnergyClarityDiverge(metrics, candidates, l10n);

    // Rule 7: low_energy_week
    _ruleLowEnergyWeek(metrics, candidates, l10n);

    // Rule 8: high_expression_all
    _ruleHighExpressionAll(metrics, candidates, l10n);

    // Rule 9: weekend_weekday_diff
    _ruleWeekendWeekdayDiff(metrics, dayFormat, candidates, l10n);

    // Rule 10: stable_week
    _ruleStableWeek(metrics, candidates, l10n);

    if (candidates.isEmpty) {
      return l10n.insight_weekly_fallback;
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.text;
  }

  // --- Individual rule implementations ---

  static void _ruleEnergySpike(
    List<DailyMetric> metrics,
    DateFormat dayFormat,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    double maxDelta = 0;
    int maxIdx = 0;
    for (var i = 1; i < metrics.length; i++) {
      final delta = (metrics[i].energy - metrics[i - 1].energy).abs();
      if (delta > maxDelta) {
        maxDelta = delta;
        maxIdx = i;
      }
    }
    if (maxDelta > 0.15) {
      final dayName = dayFormat.format(metrics[maxIdx].date);
      final direction =
          metrics[maxIdx].energy > metrics[maxIdx - 1].energy
              ? l10n.insight_direction_up
              : l10n.insight_direction_down;
      out.add(_ScoredInquiry(
        score: maxDelta * 5,
        text: l10n.insight_energy_spike(dayName, direction),
      ));
    }
  }

  static void _ruleExpressionRich(
    List<DailyMetric> metrics,
    DateFormat dayFormat,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    final most = metrics.reduce(
      (a, b) => a.expressionRange > b.expressionRange ? a : b,
    );
    if (most.expressionRange > 0.5) {
      final dayName = dayFormat.format(most.date);
      out.add(_ScoredInquiry(
        score: most.expressionRange * 1.5,
        text: l10n.insight_expression_rich(dayName),
      ));
    }
  }

  static void _ruleClarityTrend(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    if (metrics.length < 4) return;
    final mid = metrics.length ~/ 2;
    final firstHalf = metrics.sublist(0, mid);
    final secondHalf = metrics.sublist(mid);
    final avgFirst =
        firstHalf.map((m) => m.clarity).reduce((a, b) => a + b) /
            firstHalf.length;
    final avgSecond =
        secondHalf.map((m) => m.clarity).reduce((a, b) => a + b) /
            secondHalf.length;
    final diff = avgSecond - avgFirst;
    if (diff.abs() > 0.1) {
      final half = diff > 0 ? l10n.insight_half_second : l10n.insight_half_first;
      out.add(_ScoredInquiry(
        score: diff.abs() * 4,
        text: l10n.insight_clarity_trend(half),
      ));
    }
  }

  static void _ruleTempoVariation(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    final stdDev = _stdDev(metrics.map((m) => m.tempo).toList());
    if (stdDev > 0.5) {
      out.add(_ScoredInquiry(
        score: stdDev * 2,
        text: l10n.insight_tempo_variation,
      ));
    }
  }

  static void _ruleTempoConsistency(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    if (metrics.length < 3) return;
    final stdDev = _stdDev(metrics.map((m) => m.tempo).toList());
    if (stdDev < 0.2) {
      out.add(_ScoredInquiry(
        score: (1 - stdDev) * 0.8,
        text: l10n.insight_tempo_consistency,
      ));
    }
  }

  static void _ruleEnergyClarityDiverge(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    if (metrics.length < 3) return;
    final energies = metrics.map((m) => m.energy).toList();
    final clarities = metrics.map((m) => m.clarity).toList();
    final deltaE = energies.last - energies.first;
    final deltaC = clarities.last - clarities.first;
    // Diverging means different signs and both meaningful
    if ((deltaE > 0.05 && deltaC < -0.05) ||
        (deltaE < -0.05 && deltaC > 0.05)) {
      out.add(_ScoredInquiry(
        score: (deltaE - deltaC).abs() * 3,
        text: l10n.insight_energy_clarity_diverge,
      ));
    }
  }

  static void _ruleLowEnergyWeek(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    final maxE = metrics.map((m) => m.energy).reduce(math.max);
    if (maxE < 0.35) {
      out.add(_ScoredInquiry(
        score: (0.35 - maxE) * 4,
        text: l10n.insight_low_energy_week,
      ));
    }
  }

  static void _ruleHighExpressionAll(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    final minER = metrics.map((m) => m.expressionRange).reduce(math.min);
    if (minER > 0.4) {
      out.add(_ScoredInquiry(
        score: minER * 1.5,
        text: l10n.insight_high_expression,
      ));
    }
  }

  static void _ruleWeekendWeekdayDiff(
    List<DailyMetric> metrics,
    DateFormat dayFormat,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    final weekday =
        metrics.where((m) => m.date.weekday <= 5).toList();
    final weekend =
        metrics.where((m) => m.date.weekday > 5).toList();
    if (weekday.isEmpty || weekend.isEmpty) return;

    final avgWeekday =
        weekday.map((m) => m.energy).reduce((a, b) => a + b) / weekday.length;
    final avgWeekend =
        weekend.map((m) => m.energy).reduce((a, b) => a + b) / weekend.length;
    final diff = (avgWeekday - avgWeekend).abs();
    if (diff > 0.15) {
      out.add(_ScoredInquiry(
        score: diff * 3,
        text: l10n.insight_weekend_weekday_diff,
      ));
    }
  }

  static void _ruleStableWeek(
    List<DailyMetric> metrics,
    List<_ScoredInquiry> out,
    AppLocalizations l10n,
  ) {
    if (metrics.length < 3) return;
    final stdE = _stdDev(metrics.map((m) => m.energy).toList());
    final stdC = _stdDev(metrics.map((m) => m.clarity).toList());
    final stdER = _stdDev(metrics.map((m) => m.expressionRange).toList());
    final stdT = _stdDev(metrics.map((m) => m.tempo).toList());

    if (stdE < 0.1 && stdC < 0.1 && stdER < 0.1 && stdT < 0.3) {
      // Normalize tempo stddev to 0-1 scale (tempo range is 1.0-8.0, span=7)
      final stability = 1.0 - (stdE + stdC + stdER + stdT / 7.0) / 4;
      out.add(_ScoredInquiry(
        score: stability * 1.0,
        text: l10n.insight_stable_week,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // C. Monthly Comparison
  // ---------------------------------------------------------------------------

  /// Compares current month metrics with previous month recordings.
  /// Returns insight about the metric with the largest change.
  static String? generateMonthlyComparison(
    List<DailyMetric> currentMetrics,
    List<RecordingModel> prevRecordings,
    AppLocalizations l10n,
  ) {
    if (currentMetrics.isEmpty) return null;

    final prevWithData =
        prevRecordings.where((r) => r.energy != null).toList();
    if (prevWithData.isEmpty) return null;

    // Current month averages
    final curE =
        currentMetrics.map((m) => m.energy).reduce((a, b) => a + b) /
            currentMetrics.length;
    final curC =
        currentMetrics.map((m) => m.clarity).reduce((a, b) => a + b) /
            currentMetrics.length;
    final curER =
        currentMetrics.map((m) => m.expressionRange).reduce((a, b) => a + b) /
            currentMetrics.length;
    final curT =
        currentMetrics.map((m) => m.tempo).reduce((a, b) => a + b) /
            currentMetrics.length;

    // Previous month averages
    final prevE =
        prevWithData.map((r) => r.energy!).reduce((a, b) => a + b) /
            prevWithData.length;
    final prevC =
        prevWithData.where((r) => r.clarity != null).toList();
    final prevCAvg = prevC.isEmpty
        ? curC
        : prevC.map((r) => r.clarity!).reduce((a, b) => a + b) / prevC.length;
    final prevER =
        prevWithData.where((r) => r.expressionRange != null).toList();
    final prevERAvg = prevER.isEmpty
        ? curER
        : prevER.map((r) => r.expressionRange!).reduce((a, b) => a + b) /
            prevER.length;
    final prevT =
        prevWithData.where((r) => r.tempo != null).toList();
    final prevTAvg = prevT.isEmpty
        ? curT
        : prevT.map((r) => r.tempo!).reduce((a, b) => a + b) / prevT.length;

    // Find the largest change (normalize tempo to 0-1 scale; range 1.0-8.0, span=7)
    final diffs = <_MetricDiff>[
      _MetricDiff(l10n.insight_metric_energy, curE - prevE),
      _MetricDiff(l10n.insight_metric_clarity, curC - prevCAvg),
      _MetricDiff(l10n.insight_metric_expression, curER - prevERAvg),
      _MetricDiff(l10n.insight_metric_tempo, (curT - prevTAvg) / 7.0),
    ];

    diffs.sort((a, b) => b.absDiff.compareTo(a.absDiff));
    final top = diffs.first;

    if (top.absDiff < 0.05) {
      return l10n.insight_monthly_same;
    }

    final direction = top.diff > 0
        ? l10n.insight_monthly_direction_up
        : l10n.insight_monthly_direction_down;
    final nuance = _comparisonNuance(top.name, top.diff, l10n);
    return l10n.insight_monthly_change(top.name, direction, nuance);
  }

  static String _comparisonNuance(String metric, double diff, AppLocalizations l10n) {
    final absDiff = diff.abs();
    if (absDiff > 0.2) return l10n.insight_monthly_nuance_large;
    if (absDiff > 0.1) return l10n.insight_monthly_nuance_clear;
    return l10n.insight_monthly_nuance_small;
  }

  // ---------------------------------------------------------------------------
  // D. Highlight (multi-metric)
  // ---------------------------------------------------------------------------

  /// Generates a multi-line highlight showing the best day for each metric.
  static String? generateHighlight(List<DailyMetric> metrics, AppLocalizations l10n) {
    if (metrics.isEmpty) return null;

    final dayFormat = DateFormat('EEEE', l10n.localeName);

    final maxEnergy = metrics.reduce((a, b) => a.energy > b.energy ? a : b);
    final maxClarity = metrics.reduce((a, b) => a.clarity > b.clarity ? a : b);
    final maxExpr = metrics
        .reduce((a, b) => a.expressionRange > b.expressionRange ? a : b);

    final lines = <String>[
      l10n.insight_highlight_lively(dayFormat.format(maxEnergy.date)),
      l10n.insight_highlight_clear(dayFormat.format(maxClarity.date)),
    ];

    // Only add expression line if it's a different day
    if (maxExpr.date != maxEnergy.date && maxExpr.date != maxClarity.date) {
      lines.add(l10n.insight_highlight_expressive(dayFormat.format(maxExpr.date)));
    }

    return lines.join('\n');
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  static int _dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays;
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSqDiff =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return math.sqrt(sumSqDiff / values.length);
  }
}

class _ScoredInquiry {
  final double score;
  final String text;

  const _ScoredInquiry({required this.score, required this.text});
}

class _MetricDiff {
  final String name;
  final double diff;

  const _MetricDiff(this.name, this.diff);

  double get absDiff => diff.abs();
}
