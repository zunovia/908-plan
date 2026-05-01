import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';
import 'package:wav/wav.dart';

class VoiceMetrics {
  final double energy; // 0.0-1.0
  final double clarity; // 0.0-1.0
  final double expressionRange; // 0.0-1.0
  final double tempo; // syllables/sec (1.0-8.0)

  const VoiceMetrics({
    required this.energy,
    required this.clarity,
    required this.expressionRange,
    required this.tempo,
  });

  static const fallback = VoiceMetrics(
    energy: 0.5,
    clarity: 0.5,
    expressionRange: 0.4,
    tempo: 3.0,
  );
}

class VoiceAnalyzer {
  static const _windowSize = 2048;
  static const _hopSize = 512;

  /// WAVファイルを解析し、音声メトリクスを返す。
  /// 読み取り失敗時は [VoiceMetrics.fallback] を返す。
  static Future<VoiceMetrics> analyze(String filePath) async {
    final Wav wav;
    try {
      wav = await Wav.readFile(filePath);
    } catch (_) {
      return VoiceMetrics.fallback;
    }

    if (wav.channels.isEmpty || wav.channels[0].isEmpty) {
      return VoiceMetrics.fallback;
    }

    final samples = wav.channels[0];
    final sampleRate = wav.samplesPerSecond;

    final energy = _computeEnergy(samples);
    final clarity = _computeClarity(samples, sampleRate);
    final expressionRange = _computeExpressionRange(samples, sampleRate);
    final tempo = _computeTempo(samples, sampleRate);

    return VoiceMetrics(
      energy: energy,
      clarity: clarity,
      expressionRange: expressionRange,
      tempo: tempo,
    );
  }

  /// RMS振幅からエネルギーを0.0-1.0で算出。
  /// dBFS変換し、-60dB〜0dBの範囲を正規化。
  static double _computeEnergy(Float64List samples) {
    if (samples.isEmpty) return 0.0;

    double sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += s * s;
    }
    final rms = sqrt(sumSquares / samples.length);

    if (rms <= 0.0) return 0.0;

    // dBFS: 20 * log10(rms), range roughly -60..0
    final dbfs = 20.0 * log(rms) / ln10;
    return ((dbfs + 60.0) / 60.0).clamp(0.0, 1.0);
  }

  /// スペクトル重心からクラリティ(明瞭度)を0.0-1.0で算出。
  /// 高い重心 = クリアな発声。
  static double _computeClarity(Float64List samples, int sampleRate) {
    final frames = _stftMagnitudes(samples);
    if (frames.isEmpty) return 0.5;

    final binFreqStep = sampleRate / _windowSize;
    double totalCentroid = 0.0;
    int frameCount = 0;

    for (final magnitudes in frames) {
      double weightedSum = 0.0;
      double magSum = 0.0;

      for (int i = 0; i < magnitudes.length; i++) {
        final freq = i * binFreqStep;
        weightedSum += freq * magnitudes[i];
        magSum += magnitudes[i];
      }

      if (magSum > 0.0) {
        totalCentroid += weightedSum / magSum;
        frameCount++;
      }
    }

    if (frameCount == 0) return 0.5;

    final meanCentroid = totalCentroid / frameCount;
    // 正規化: 人間の声は100-4000Hz、重心は典型的に500-3000Hz
    // 500Hz → 0.0, 3000Hz → 1.0
    return ((meanCentroid - 500.0) / 2500.0).clamp(0.0, 1.0);
  }

  /// F0（基本周波数）の変動から表現の豊かさを0.0-1.0で算出。
  /// 標準偏差が大きい = 抑揚が豊か。
  static double _computeExpressionRange(
    Float64List samples,
    int sampleRate,
  ) {
    final frames = _stftMagnitudes(samples);
    if (frames.isEmpty) return 0.4;

    final binFreqStep = sampleRate / _windowSize;
    // F0検出範囲: 80-400Hz
    final minBin = (80.0 / binFreqStep).ceil();
    final maxBin = (400.0 / binFreqStep).floor();

    final f0Values = <double>[];

    for (final magnitudes in frames) {
      if (maxBin >= magnitudes.length) continue;

      double peakMag = 0.0;
      int peakBin = minBin;

      for (int i = minBin; i <= maxBin; i++) {
        if (magnitudes[i] > peakMag) {
          peakMag = magnitudes[i];
          peakBin = i;
        }
      }

      // ピークが十分な振幅を持つ場合のみ有効なF0とする
      if (peakMag > 0.01) {
        f0Values.add(peakBin * binFreqStep);
      }
    }

    if (f0Values.length < 2) return 0.4;

    // F0系列の標準偏差
    double sum = 0.0;
    for (final f in f0Values) {
      sum += f;
    }
    final mean = sum / f0Values.length;

    double variance = 0.0;
    for (final f in f0Values) {
      variance += (f - mean) * (f - mean);
    }
    final stdDev = sqrt(variance / f0Values.length);

    // 正規化: stdDev 0-80Hz → 0.0-1.0
    // 一般的な話し声のF0変動は20-60Hz程度
    return (stdDev / 80.0).clamp(0.0, 1.0);
  }

  /// エネルギーエンベロープのピーク検出から音節レートを推定。
  static double _computeTempo(Float64List samples, int sampleRate) {
    if (samples.isEmpty || sampleRate == 0) return 3.0;

    final durationSec = samples.length / sampleRate;
    if (durationSec < 0.5) return 3.0;

    // 50msウィンドウでRMSエンベロープを計算
    final envelopeWindowSize = (sampleRate * 0.05).round();
    if (envelopeWindowSize == 0) return 3.0;

    final envelopeLength = samples.length ~/ envelopeWindowSize;
    if (envelopeLength < 3) return 3.0;

    final envelope = Float64List(envelopeLength);
    for (int i = 0; i < envelopeLength; i++) {
      double sum = 0.0;
      final start = i * envelopeWindowSize;
      for (int j = 0; j < envelopeWindowSize; j++) {
        final s = samples[start + j];
        sum += s * s;
      }
      envelope[i] = sqrt(sum / envelopeWindowSize);
    }

    // 移動平均で平滑化 (5点)
    final smoothed = Float64List(envelopeLength);
    for (int i = 0; i < envelopeLength; i++) {
      double avg = 0.0;
      int count = 0;
      for (int j = max(0, i - 2); j <= min(envelopeLength - 1, i + 2); j++) {
        avg += envelope[j];
        count++;
      }
      smoothed[i] = avg / count;
    }

    // ピーク検出（立ち上がりエッジ = 音節開始）
    // 閾値: 平均エンベロープの50%
    double envMean = 0.0;
    for (final v in smoothed) {
      envMean += v;
    }
    envMean /= smoothed.length;

    final threshold = envMean * 0.5;
    int peakCount = 0;
    bool belowThreshold = true;

    for (int i = 1; i < smoothed.length; i++) {
      if (belowThreshold && smoothed[i] > threshold) {
        // 立ち上がりエッジ検出
        if (i > 0 && smoothed[i] > smoothed[i - 1]) {
          peakCount++;
          belowThreshold = false;
        }
      } else if (smoothed[i] < threshold) {
        belowThreshold = true;
      }
    }

    if (peakCount == 0) return 3.0;

    final syllablesPerSec = peakCount / durationSec;
    // 妥当な範囲にクランプ (1.0-8.0 syllables/sec)
    return syllablesPerSec.clamp(1.0, 8.0);
  }

  /// STFT を実行し、各フレームの振幅スペクトルを返す。
  static List<Float64List> _stftMagnitudes(Float64List samples) {
    if (samples.length < _windowSize) return [];

    final fft = FFT(_windowSize);
    final window = Window.hanning(_windowSize);
    final frames = <Float64List>[];

    for (int start = 0;
        start + _windowSize <= samples.length;
        start += _hopSize) {
      // ウィンドウ適用
      final windowed = Float64List(_windowSize);
      for (int i = 0; i < _windowSize; i++) {
        windowed[i] = samples[start + i] * window[i];
      }

      final spectrum = fft.realFft(windowed);
      // realFft returns Float64x2List (complex pairs), compute magnitudes
      final numBins = spectrum.length;
      final magnitudes = Float64List(numBins);
      for (int i = 0; i < numBins; i++) {
        final re = spectrum[i].x;
        final im = spectrum[i].y;
        magnitudes[i] = sqrt(re * re + im * im);
      }

      frames.add(magnitudes);
    }

    return frames;
  }
}
