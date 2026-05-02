import 'dart:math' as math;

import '../../features/reports/data/report_model.dart';

/// Represents the user's current convergence towards ZERO.
///
/// Score ranges 0-100. Lower is better:
///   0 = perfectly stable voice (ZERO state)
///   100 = highly variable voice
///
/// Stage thresholds:
///   score >= 80 → Stage 5 (most variable)
///   score >= 60 → Stage 4
///   score >= 40 → Stage 3
///   score >= 20 → Stage 2
///   score >=  5 → Stage 1
///   score <   5 → ZERO
class ZeroScore {
  final int score;
  final int stage;
  final String stageLabel;

  const ZeroScore({
    required this.score,
    required this.stage,
    required this.stageLabel,
  });

  /// Computes ZeroScore from the last 7 days of daily metrics.
  /// Returns null if fewer than 7 data points are available.
  static ZeroScore? compute(List<DailyMetric> metrics) {
    if (metrics.length < 7) return null;

    // Use the most recent 7 metrics sorted by date
    final sorted = [...metrics]..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;

    // Calculate stdDev for each metric
    final stdEnergy = _stdDev(recent.map((m) => m.energy).toList());
    final stdClarity = _stdDev(recent.map((m) => m.clarity).toList());
    final stdExpression = _stdDev(recent.map((m) => m.expressionRange).toList());
    final stdTempo = _stdDev(recent.map((m) => m.tempo).toList());

    // Normalize each stdDev to 0-1 range:
    // energy, clarity, expressionRange: natural range 0.0-1.0, max stdDev ~ 0.5
    // tempo: range 1.0-8.0 (span = 7.0), normalize by /7.0 to match InsightEngine
    const maxStd = 0.5; // approximate max stdDev for 0-1 bounded metrics
    final normEnergy = (stdEnergy / maxStd).clamp(0.0, 1.0);
    final normClarity = (stdClarity / maxStd).clamp(0.0, 1.0);
    final normExpression = (stdExpression / maxStd).clamp(0.0, 1.0);
    final normTempo = (stdTempo / 7.0).clamp(0.0, 1.0);

    final avgNorm = (normEnergy + normClarity + normExpression + normTempo) / 4.0;
    final score = (avgNorm * 100).round().clamp(0, 100);

    return ZeroScore(
      score: score,
      stage: _stageFor(score),
      stageLabel: _stageLabelFor(score),
    );
  }

  static int _stageFor(int score) {
    if (score >= 80) return 5;
    if (score >= 60) return 4;
    if (score >= 40) return 3;
    if (score >= 20) return 2;
    if (score >= 5) return 1;
    return 0;
  }

  static String _stageLabelFor(int score) {
    if (score >= 80) return 'Stage 5';
    if (score >= 60) return 'Stage 4';
    if (score >= 40) return 'Stage 3';
    if (score >= 20) return 'Stage 2';
    if (score >= 5) return 'Stage 1';
    return 'ZERO';
  }

  static double _stdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSqDiff =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return math.sqrt(sumSqDiff / values.length);
  }

  /// Returns per-metric normalized stdDev values (0.0-1.0) for ring display.
  static ZeroRingData? computeRingData(List<DailyMetric> metrics) {
    if (metrics.length < 7) return null;

    final sorted = [...metrics]..sort((a, b) => a.date.compareTo(b.date));
    final recent = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;

    final stdEnergy = _stdDev(recent.map((m) => m.energy).toList());
    final stdClarity = _stdDev(recent.map((m) => m.clarity).toList());
    final stdExpression = _stdDev(recent.map((m) => m.expressionRange).toList());
    final stdTempo = _stdDev(recent.map((m) => m.tempo).toList());

    const maxStd = 0.5;
    return ZeroRingData(
      energy: (stdEnergy / maxStd).clamp(0.0, 1.0),
      clarity: (stdClarity / maxStd).clamp(0.0, 1.0),
      expressionRange: (stdExpression / maxStd).clamp(0.0, 1.0),
      tempo: (stdTempo / 7.0).clamp(0.0, 1.0),
    );
  }
}

/// Per-metric variability data for the convergence ring widget.
class ZeroRingData {
  /// Normalized [0.0, 1.0] — 0.0 = perfectly stable, 1.0 = highly variable
  final double energy;
  final double clarity;
  final double expressionRange;
  final double tempo;

  const ZeroRingData({
    required this.energy,
    required this.clarity,
    required this.expressionRange,
    required this.tempo,
  });
}
