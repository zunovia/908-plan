// キー不要の規則ベース解析（感情・引用語・トリガー・FAQ）。Luckarise の RuleRoute.kt を移植。純 Dart。

import 'dart:math';

import 'content_models.dart';
import 'english_stemmer.dart';
import 'models.dart';
import 'text_normalizer.dart';

class RuleAnalysis {
  const RuleAnalysis({
    required this.emotion,
    required this.quoteWord,
    required this.trigger,
    required this.faqId,
    required this.scores,
  });

  final EmotionTag? emotion;

  /// 反映文の {w} に差し込む引用語。
  final String? quoteWord;
  final TriggerKind trigger;
  final String? faqId;
  final Map<EmotionTag, int> scores;
}

class RuleRoute {
  const RuleRoute(this.lexicons, this.triggerLex, this.faqs);

  final Map<AppLang, Lexicon> lexicons;
  final Map<AppLang, Triggers> triggerLex;
  final Map<AppLang, List<FaqItem>> faqs;

  RuleAnalysis analyze(String text, AppLang lang, EmotionTag? emotionHint) {
    final lexicon = lexicons[lang];
    // LexiconEntry は同一インスタンスで数える（Kotlin の LinkedHashMap と同じく挿入順を保つ）。
    final entryScore = <LexiconEntry, int>{};
    final emotionScore = <EmotionTag, int>{};

    if (lexicon != null) {
      if (lang == AppLang.ja) {
        _scoreJapanese(text, lexicon, entryScore);
      } else {
        _scoreEnglish(text, lexicon, entryScore);
      }
      entryScore.forEach((entry, score) {
        final emotion = enumByName(EmotionTag.values, entry.emotion);
        if (emotion == null) return;
        emotionScore[emotion] = (emotionScore[emotion] ?? 0) + score;
      });
    }

    if (emotionHint != null) {
      emotionScore[emotionHint] = (emotionScore[emotionHint] ?? 0) + 3;
    }

    EmotionTag? emotion;
    if (emotionScore.isEmpty) {
      emotion = emotionHint;
    } else {
      final maxScore = emotionScore.values.reduce(max);
      final top = emotionScore.entries.where((e) => e.value == maxScore).map((e) => e.key).toList();
      emotion = EmotionTag.priority.firstWhere(top.contains, orElse: () => top.first);
    }

    String? quoteWord;
    if (entryScore.isNotEmpty) {
      LexiconEntry? best;
      var bestScore = 0;
      entryScore.forEach((entry, score) {
        if (best == null || score > bestScore) {
          best = entry;
          bestScore = score;
        }
      });
      quoteWord = best?.quote;
    }

    return RuleAnalysis(
      emotion: emotion,
      quoteWord: quoteWord,
      trigger: _resolveTrigger(text, lang),
      faqId: _resolveFaq(text, lang),
      scores: Map.unmodifiable(emotionScore),
    );
  }

  void _scoreJapanese(String text, Lexicon lexicon, Map<LexiconEntry, int> entryScore) {
    final compact = TextNormalizer.jaCompact(text);
    int? contrastIndex;
    for (final marker in lexicon.contrasts) {
      final m = TextNormalizer.jaCompact(marker);
      if (m.isEmpty) continue;
      final idx = compact.indexOf(m);
      if (idx >= 0 && (contrastIndex == null || idx < contrastIndex)) contrastIndex = idx;
    }
    final negs = lexicon.negations.map(TextNormalizer.jaCompact).where((n) => n.isNotEmpty).toList();
    final ints = lexicon.intensifiers.map(TextNormalizer.jaCompact).where((n) => n.isNotEmpty).toList();

    for (final entry in lexicon.entries) {
      var total = 0;
      for (final term in entry.terms) {
        final compactTerm = TextNormalizer.jaCompact(term);
        if (compactTerm.isEmpty) continue;
        var searchFrom = 0;
        while (true) {
          final pos = compact.indexOf(compactTerm, searchFrom);
          if (pos < 0) break;
          final matchEnd = pos + compactTerm.length;
          searchFrom = matchEnd;

          final termEndsWithNegation = negs.any(compactTerm.endsWith);
          if (!termEndsWithNegation) {
            final windowEnd = min(compact.length, matchEnd + 6);
            final window = compact.substring(matchEnd, windowEnd);
            if (negs.any(window.contains)) continue;
          }

          var contribution = entry.weight;
          if (contrastIndex != null && pos >= contrastIndex) contribution *= 2;

          // 強調語が一致の開始位置より手前・6 文字以内にあれば +1。
          final before = compact.substring(max(0, pos - 6), pos);
          if (ints.any(before.contains)) contribution += 1;

          total += contribution;
        }
      }
      if (total != 0) entryScore[entry] = (entryScore[entry] ?? 0) + total;
    }
  }

  void _scoreEnglish(String text, Lexicon lexicon, Map<LexiconEntry, int> entryScore) {
    final tokens = TextNormalizer.enTokens(text);
    final stemmed = tokens.map(EnglishStemmer.stem).toList();

    int? contrastTokenIndex;
    for (final marker in lexicon.contrasts) {
      final idx = stemmed.indexOf(EnglishStemmer.stem(TextNormalizer.normBase(marker)));
      if (idx >= 0 && (contrastTokenIndex == null || idx < contrastTokenIndex)) {
        contrastTokenIndex = idx;
      }
    }
    final negStems = lexicon.negations.map((n) => EnglishStemmer.stem(TextNormalizer.normBase(n))).toSet();
    final intStems =
        lexicon.intensifiers.map((n) => EnglishStemmer.stem(TextNormalizer.normBase(n))).toSet();

    for (final entry in lexicon.entries) {
      var total = 0;
      for (final term in entry.terms) {
        final termStems = EnglishStemmer.stemPhrase(TextNormalizer.normBase(term));
        if (termStems.isEmpty) continue;
        var i = 0;
        while (i <= stemmed.length - termStems.length) {
          var isMatch = true;
          for (var j = 0; j < termStems.length; j++) {
            if (stemmed[i + j] != termStems[j]) {
              isMatch = false;
              break;
            }
          }
          if (isMatch) {
            var negated = false;
            for (var idx = max(0, i - 3); idx < i; idx++) {
              if (negStems.contains(stemmed[idx])) {
                negated = true;
                break;
              }
            }
            if (!negated) {
              var contribution = entry.weight;
              if (contrastTokenIndex != null && i >= contrastTokenIndex) contribution *= 2;
              // 強調語の次トークンが一致語なら +1。
              if (i > 0 && intStems.contains(stemmed[i - 1])) contribution += 1;
              total += contribution;
            }
            i += termStems.length;
          } else {
            i += 1;
          }
        }
      }
      if (total != 0) entryScore[entry] = (entryScore[entry] ?? 0) + total;
    }
  }

  TriggerKind _resolveTrigger(String text, AppLang lang) {
    final lex = triggerLex[lang];
    if (lex == null) return TriggerKind.UNKNOWN;
    final other = _countTermMatches(text, lang, lex.other);
    final self = _countTermMatches(text, lang, lex.self);
    final urge = _countTermMatches(text, lang, lex.urge);
    final m = max(other, max(self, urge));
    if (m == 0) return TriggerKind.UNKNOWN;
    if (other == m) return TriggerKind.OTHER;
    if (self == m) return TriggerKind.SELF;
    return TriggerKind.URGE;
  }

  int _countTermMatches(String text, AppLang lang, List<String> terms) {
    if (terms.isEmpty) return 0;
    if (lang == AppLang.ja) {
      final compact = TextNormalizer.jaCompact(text);
      return terms.where((t) {
        final ct = TextNormalizer.jaCompact(t);
        return ct.isNotEmpty && compact.contains(ct);
      }).length;
    }
    final tokens = TextNormalizer.enTokens(text);
    return terms.where((t) => t.isNotEmpty && TextNormalizer.enContainsPhrase(tokens, t)).length;
  }

  String? _resolveFaq(String text, AppLang lang) {
    final items = faqs[lang];
    if (items == null) return null;
    final compact = lang == AppLang.ja ? TextNormalizer.jaCompact(text) : '';
    final tokens = lang == AppLang.ja ? const <String>[] : TextNormalizer.enTokens(text);
    for (final item in items) {
      final matched = lang == AppLang.ja
          ? item.patterns.any((p) {
              final cp = TextNormalizer.jaCompact(p);
              return cp.isNotEmpty && compact.contains(cp);
            })
          : item.patterns.any((p) => TextNormalizer.enContainsPhrase(tokens, p));
      if (matched) return item.id;
    }
    return null;
  }
}
