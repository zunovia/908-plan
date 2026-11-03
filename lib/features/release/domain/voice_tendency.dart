// 声の傾向タグ（Voxna 独自）。録音の値を、それより前の直近の録音の平均と比べて、
// 目立つ違いを最大 2 つのタグにする。Write の記憶チップの下書き（選択済みチップ）に使う。
// 純 Dart（RecordingModel は flutter を import しない）。評価・診断はしない。事実の差だけ。

import '../../recording/data/recording_model.dart';

/// 声の値（RecordingModel の 4 指標。null は未計測）。
class VoiceMetrics {
  const VoiceMetrics({this.energy, this.clarity, this.expressionRange, this.tempo});

  factory VoiceMetrics.of(RecordingModel r) => VoiceMetrics(
        energy: r.energy,
        clarity: r.clarity,
        expressionRange: r.expressionRange,
        tempo: r.tempo,
      );

  /// 0.0〜1.0
  final double? energy;

  /// 0.0〜1.0
  final double? clarity;

  /// 0.0〜1.0
  final double? expressionRange;

  /// 音節/秒（おおよそ 1.0〜8.0）
  final double? tempo;
}

class VoiceTendency {
  const VoiceTendency._();

  static const String lowEnergy = 'voice:low_energy';
  static const String fastTempo = 'voice:fast_tempo';
  static const String narrowRange = 'voice:narrow_range';
  static const String lowClarity = 'voice:low_clarity';
  static const String steady = 'voice:steady';

  /// 出しうるタグ（UI で l10n の文言に置き換える）。
  static const List<String> allTags = [lowEnergy, fastTempo, narrowRange, lowClarity, steady];

  /// ベースラインに使う直近の録音数の上限。
  static const int baselineWindow = 14;

  /// ベースラインに必要な最少の録音数（これ未満ならタグを出さない）。
  static const int minBaseline = 3;

  /// 0〜1 の指標で「違う」とみなす最小の差（絶対値）と、その割合（平均比）。
  static const double _levelAbs = 0.08;
  static const double _levelRatio = 0.15;

  /// テンポで「速い」とみなす最小の差（音節/秒）と割合。
  static const double _tempoAbs = 0.4;
  static const double _tempoRatio = 0.12;

  /// 「いつもどおり」とみなす割合（全指標がこの範囲内）。
  static const double _steadyRatio = 0.06;

  /// タグ（最大 [maxTags] 個）。値は "voice:..." の文字列。
  static List<String> tagsFor(VoiceMetrics current, List<VoiceMetrics> baseline, {int maxTags = 2}) {
    if (baseline.length < minBaseline || maxTags <= 0) return const [];
    final base = baseline.length > baselineWindow ? baseline.sublist(0, baselineWindow) : baseline;

    final mEnergy = _mean(base.map((b) => b.energy));
    final mClarity = _mean(base.map((b) => b.clarity));
    final mRange = _mean(base.map((b) => b.expressionRange));
    final mTempo = _mean(base.map((b) => b.tempo));

    final scored = <({String tag, double score})>[];
    void lower(String tag, double? value, double? mean) {
      if (value == null || mean == null || mean <= 0) return;
      final diff = mean - value;
      if (diff >= _levelAbs && diff / mean >= _levelRatio) scored.add((tag: tag, score: diff / mean));
    }

    lower(lowEnergy, current.energy, mEnergy);
    lower(narrowRange, current.expressionRange, mRange);
    lower(lowClarity, current.clarity, mClarity);
    final tempo = current.tempo;
    if (tempo != null && mTempo != null && mTempo > 0) {
      final diff = tempo - mTempo;
      if (diff >= _tempoAbs && diff / mTempo >= _tempoRatio) {
        scored.add((tag: fastTempo, score: diff / mTempo));
      }
    }

    if (scored.isNotEmpty) {
      // 違いの大きい順。同じならタグの並び（allTags の順）。
      scored.sort((a, b) {
        final c = b.score.compareTo(a.score);
        return c != 0 ? c : allTags.indexOf(a.tag).compareTo(allTags.indexOf(b.tag));
      });
      return scored.take(maxTags).map((e) => e.tag).toList();
    }

    // 目立つ違いが無く、比べられた指標がすべて平均の ±6% 以内なら「いつもどおり」。
    var compared = 0;
    var allClose = true;
    void close(double? value, double? mean) {
      if (value == null || mean == null || mean <= 0) return;
      compared++;
      if ((value - mean).abs() / mean > _steadyRatio) allClose = false;
    }

    close(current.energy, mEnergy);
    close(current.clarity, mClarity);
    close(current.expressionRange, mRange);
    close(current.tempo, mTempo);
    return (compared >= 2 && allClose) ? const [steady] : const [];
  }

  /// 録音から。[previous] はそれより前の録音（順不同）。同じ id・[current] 以降の録音は除き、新しい順に直近 14 件を使う。
  static List<String> tagsForRecording(
    RecordingModel current,
    List<RecordingModel> previous, {
    int maxTags = 2,
  }) {
    final before = previous
        .where((r) => r.id != current.id && r.recordedAt.isBefore(current.recordedAt))
        .toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return tagsFor(
      VoiceMetrics.of(current),
      before.take(baselineWindow).map(VoiceMetrics.of).toList(),
      maxTags: maxTags,
    );
  }

  static double? _mean(Iterable<double?> values) {
    var sum = 0.0;
    var n = 0;
    for (final v in values) {
      if (v == null) continue;
      sum += v;
      n++;
    }
    return n == 0 ? null : sum / n;
  }
}
