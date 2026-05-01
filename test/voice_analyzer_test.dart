import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/core/audio/voice_analyzer.dart';

void main() {
  group('VoiceMetrics', () {
    test('fallback values are within declared ranges', () {
      const f = VoiceMetrics.fallback;
      expect(f.energy, inInclusiveRange(0.0, 1.0));
      expect(f.clarity, inInclusiveRange(0.0, 1.0));
      expect(f.expressionRange, inInclusiveRange(0.0, 1.0));
      expect(f.tempo, inInclusiveRange(1.0, 8.0));
    });
  });

  group('VoiceAnalyzer.analyze', () {
    test('returns fallback for non-existent file path', () async {
      final metrics = await VoiceAnalyzer.analyze('/non/existent/file.wav');
      expect(metrics.energy, VoiceMetrics.fallback.energy);
      expect(metrics.clarity, VoiceMetrics.fallback.clarity);
      expect(metrics.expressionRange, VoiceMetrics.fallback.expressionRange);
      expect(metrics.tempo, VoiceMetrics.fallback.tempo);
    });
  });

  group('VoiceAnalyzer metric range contract', () {
    test('fallback energy is within 0-1', () {
      expect(VoiceMetrics.fallback.energy, inInclusiveRange(0.0, 1.0));
    });

    test('fallback clarity is within 0-1', () {
      expect(VoiceMetrics.fallback.clarity, inInclusiveRange(0.0, 1.0));
    });

    test('fallback expressionRange is within 0-1', () {
      expect(VoiceMetrics.fallback.expressionRange, inInclusiveRange(0.0, 1.0));
    });

    test('fallback tempo is within 1-8', () {
      expect(VoiceMetrics.fallback.tempo, inInclusiveRange(1.0, 8.0));
    });
  });
}
