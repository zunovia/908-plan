import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/home/data/daily_prompts.dart';

void main() {
  group('getDailyPrompt', () {
    test('returns non-empty string for day 0', () {
      final prompt = getDailyPrompt(0);
      expect(prompt, isNotEmpty);
    });

    test('returns non-empty string for large day numbers', () {
      final prompt = getDailyPrompt(365);
      expect(prompt, isNotEmpty);
    });

    test('cycles through prompts', () {
      // There are 20 prompts, so day 0 and day 20 should return the same
      final prompt0 = getDailyPrompt(0);
      final prompt20 = getDailyPrompt(20);
      expect(prompt0, prompt20);
    });

    test('different days return different prompts within cycle', () {
      final prompt0 = getDailyPrompt(0);
      final prompt1 = getDailyPrompt(1);
      expect(prompt0, isNot(prompt1));
    });

    test('never throws for any non-negative day', () {
      for (int i = 0; i < 100; i++) {
        expect(() => getDailyPrompt(i), returnsNormally);
      }
    });
  });
}
