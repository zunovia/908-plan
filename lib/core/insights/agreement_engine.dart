import '../../features/recording/data/recording_model.dart';

/// Result of comparing self-assessment ("一呼吸タップ") with an estimate
/// derived from the voice metrics over a window of days.
class AgreementResult {
  /// Number of recordings in the current window where both agreed.
  final int matched;

  /// Number of recordings in the current window that had a usable
  /// self-assessment (calm / normal / shaky) and metrics.
  final int total;

  /// Agreement rate of the previous window (same length), if available.
  final double? previousRate;

  const AgreementResult({
    required this.matched,
    required this.total,
    this.previousRate,
  });

  static const empty = AgreementResult(matched: 0, total: 0);

  double? get rate => total == 0 ? null : matched / total;

  bool get hasEnoughData => total >= AgreementEngine.minimumSamples;

  /// True when the rate rose clearly compared with the previous window.
  bool get isRising {
    final current = rate;
    final previous = previousRate;
    if (current == null || previous == null) return false;
    if (!hasEnoughData) return false;
    return current - previous >= AgreementEngine.risingThreshold;
  }
}

/// Subjective-objective agreement ("主観-客観一致率").
///
/// The estimate is a deliberately simple heuristic over the four metrics.
/// It is not a clinical measure; it exists so that the user's own sense and
/// the data can be compared over time.
class AgreementEngine {
  AgreementEngine._();

  static const int windowDays = 14;
  static const int minimumSamples = 3;
  static const double risingThreshold = 0.15;

  static const String calm = 'calm';
  static const String normal = 'normal';
  static const String shaky = 'shaky';

  /// Turbulence score in 0.0-1.0 from the metrics (higher = more unsettled).
  static double? turbulence(RecordingModel r) {
    final energy = r.energy;
    final expression = r.expressionRange;
    final tempo = r.tempo;
    if (energy == null || expression == null || tempo == null) return null;

    final tempoDeviation = ((tempo - 3.0).abs() / 2.0).clamp(0.0, 1.0);
    final energyDeviation = ((energy - 0.5).abs() * 2.0).clamp(0.0, 1.0);
    final value = 0.45 * expression.clamp(0.0, 1.0) +
        0.35 * tempoDeviation +
        0.20 * energyDeviation;
    return value.clamp(0.0, 1.0);
  }

  /// Estimated assessment (calm / normal / shaky) from the metrics,
  /// or null when metrics are missing.
  static String? estimate(RecordingModel r) {
    final t = turbulence(r);
    if (t == null) return null;
    if (t < 0.30) return calm;
    if (t < 0.55) return normal;
    return shaky;
  }

  static bool _isUsable(String? assessment) =>
      assessment == calm || assessment == normal || assessment == shaky;

  /// Computes agreement over the last [windowDays] ending at [now], and the
  /// window before it for trend detection.
  static AgreementResult compute(
    List<RecordingModel> recordings, {
    required DateTime now,
    int windowDays = windowDays,
  }) {
    final currentStart = now.subtract(Duration(days: windowDays));
    final previousStart = currentStart.subtract(Duration(days: windowDays));

    var matched = 0;
    var total = 0;
    var prevMatched = 0;
    var prevTotal = 0;

    for (final r in recordings) {
      if (!_isUsable(r.selfAssessment)) continue;
      final est = estimate(r);
      if (est == null) continue;
      final hit = est == r.selfAssessment;

      if (!r.recordedAt.isBefore(currentStart) && !r.recordedAt.isAfter(now)) {
        total++;
        if (hit) matched++;
      } else if (!r.recordedAt.isBefore(previousStart) &&
          r.recordedAt.isBefore(currentStart)) {
        prevTotal++;
        if (hit) prevMatched++;
      }
    }

    return AgreementResult(
      matched: matched,
      total: total,
      previousRate:
          prevTotal >= minimumSamples ? prevMatched / prevTotal : null,
    );
  }
}
