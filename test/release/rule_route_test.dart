import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/rule_route.dart';

import 'release_test_helpers.dart';

void main() {
  const enLexicon = Lexicon(
    entries: [
      LexiconEntry(emotion: 'ANXIETY', terms: ['worried', 'nervous'], quote: 'it will be okay', weight: 2),
      LexiconEntry(emotion: 'ANGER', terms: ['furious'], quote: 'let it go', weight: 2),
    ],
    intensifiers: ['really', 'very'],
    negations: ['not', 'never'],
    contrasts: ['but'],
  );
  const jaLexicon = Lexicon(
    entries: [
      LexiconEntry(emotion: 'ANXIETY', terms: ['不安'], quote: '大丈夫', weight: 2),
      LexiconEntry(emotion: 'ANGER', terms: ['怒り'], quote: '手放す', weight: 2),
    ],
    intensifiers: ['とても'],
    negations: ['ない'],
    contrasts: ['でも'],
  );

  group('RuleRoute synthetic (Kotlin RuleRouteTest)', () {
    test('en negation within 3 tokens suppresses the match', () {
      const route = RuleRoute({AppLang.en: enLexicon}, {}, {});
      expect(route.analyze('I am not worried about it', AppLang.en, null).emotion, isNull);
    });

    test('en intensifier immediately before the match boosts score', () {
      const route = RuleRoute({AppLang.en: enLexicon}, {}, {});
      final a = route.analyze('I am very worried', AppLang.en, null);
      expect(a.emotion, EmotionTag.ANXIETY);
      expect(a.scores[EmotionTag.ANXIETY], 3);
      expect(a.quoteWord, 'it will be okay');
    });

    test('en contrast doubles score after marker', () {
      const route = RuleRoute({AppLang.en: enLexicon}, {}, {});
      final a = route.analyze('I was fine but furious', AppLang.en, null);
      expect(a.emotion, EmotionTag.ANGER);
      expect(a.scores[EmotionTag.ANGER], 4);
    });

    test('ja negation within 6 chars suppresses the match', () {
      const route = RuleRoute({AppLang.ja: jaLexicon}, {}, {});
      expect(route.analyze('不安はない', AppLang.ja, null).emotion, isNull);
    });

    test('ja intensifier boosts score', () {
      const route = RuleRoute({AppLang.ja: jaLexicon}, {}, {});
      final a = route.analyze('とても不安です', AppLang.ja, null);
      expect(a.emotion, EmotionTag.ANXIETY);
      expect(a.scores[EmotionTag.ANXIETY], 3);
    });

    test('hint only with empty text uses emotionHint', () {
      const route = RuleRoute({AppLang.en: enLexicon}, {}, {});
      final a = route.analyze('', AppLang.en, EmotionTag.SADNESS);
      expect(a.emotion, EmotionTag.SADNESS);
      expect(a.quoteWord, isNull);
    });

    test('ties are broken by EmotionTag.priority', () {
      const lex = Lexicon(entries: [
        LexiconEntry(emotion: 'ANGER', terms: ['mad']),
        LexiconEntry(emotion: 'IMPATIENCE', terms: ['late']),
      ]);
      const route = RuleRoute({AppLang.en: lex}, {}, {});
      expect(route.analyze('mad and late', AppLang.en, null).emotion, EmotionTag.IMPATIENCE);
    });

    test('trigger: OTHER wins ties, then SELF, then URGE; none is UNKNOWN', () {
      const route = RuleRoute({}, {
        AppLang.en: Triggers(other: ['my boss'], self: ['my fault'], urge: ['i want']),
      }, {});
      expect(route.analyze('my boss and my fault', AppLang.en, null).trigger, TriggerKind.OTHER);
      expect(route.analyze('it was my fault', AppLang.en, null).trigger, TriggerKind.SELF);
      expect(route.analyze('i want cake', AppLang.en, null).trigger, TriggerKind.URGE);
      expect(route.analyze('hello', AppLang.en, null).trigger, TriggerKind.UNKNOWN);
    });

    test('faq pattern is detected', () {
      const route = RuleRoute({}, {}, {
        AppLang.en: [
          FaqItem('FAQ1', ['not working'], 'answer'),
        ],
      });
      expect(route.analyze('this is not working', AppLang.en, null).faqId, 'FAQ1');
      expect(route.analyze('fine', AppLang.en, null).faqId, isNull);
    });
  });

  group('RuleRoute fixtures (rule_cases.json × production lexicons)', () {
    final fixture = jsonDecode(readUtf8(releaseFixture('rule_cases.json'))) as Map<String, dynamic>;
    for (final code in ['en', 'ja']) {
      final lang = AppLang.values.byName(code);
      final route = RuleRoute(
        {lang: Lexicon.parse(readUtf8(releaseAsset(code, 'lexicon.json')))},
        {lang: Triggers.parse(readUtf8(releaseAsset(code, 'triggers.json')))},
        {lang: FaqFile.parse(readUtf8(releaseAsset(code, 'faq.json'))).items},
      );
      for (final raw in (fixture[code] as List? ?? const [])) {
        final c = raw as Map<String, dynamic>;
        final text = c['text'] as String;
        test('[$code] $text', () {
          final a = route.analyze(text, lang, null);
          final emotion = c['emotion'] as String?;
          final trigger = c['trigger'] as String?;
          if (emotion != null) expect(a.emotion, EmotionTag.values.byName(emotion), reason: text);
          if (trigger != null) expect(a.trigger, TriggerKind.values.byName(trigger), reason: text);
        });
      }
    }
  });
}
