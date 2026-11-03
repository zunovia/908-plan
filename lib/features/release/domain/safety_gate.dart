// 入力テキストの安全性判定。Luckarise の domain/safety/SafetyGate.kt を移植。純 Dart。
// 危機辞書は言語ごとに完結し、他言語へフォールバックしない。

import 'content_models.dart';
import 'models.dart';
import 'text_normalizer.dart';

class SafetyResult {
  const SafetyResult(this.level, this.abuseContext, this.categories);

  static const SafetyResult ok = SafetyResult(SafetyLevel.OK, false, <String>{});

  final SafetyLevel level;

  /// 虐待・ハラスメントの文脈（再生リマインドやカードを出さない／窓口の ABUSE を先頭に）。
  final bool abuseContext;

  /// 一致したカテゴリ（direct / indirect / harm / abuse / harassment / soft / caution）。
  final Set<String> categories;

  bool get isCrisis => level == SafetyLevel.CRISIS;
  bool get isSoft => level == SafetyLevel.CRISIS_SOFT;

  @override
  String toString() => 'SafetyResult($level, abuse=$abuseContext, $categories)';
}

class _Representation {
  const _Representation(this.raw, this.stripped);

  /// 除外語句だけを取り除いたもの。
  final String raw;

  /// さらに強調・つなぎ語を取り除いたもの。
  final String stripped;
}

class SafetyGate {
  const SafetyGate(this.dicts);

  final Map<AppLang, CrisisLexicon> dicts;

  /// [checkInput] の別名（言語は文字種から自動で決まるため [lang] は使わない）。
  SafetyResult check(String text, [AppLang? lang]) => checkInput(text);

  /// かな・漢字を含めば ja 辞書、ラテン文字を含めば en / es / pt 辞書を引き、最も重い判定を返す。
  SafetyResult checkInput(String text) {
    final langs = <AppLang>[];
    final kana = _containsKana(text);
    final ascii = _containsAscii(text);
    if (kana && dicts.containsKey(AppLang.ja)) langs.add(AppLang.ja);
    if (ascii && dicts.containsKey(AppLang.en)) langs.add(AppLang.en);
    // スペイン語・ポルトガル語はラテン文字なので英語と同じ入口で辞書を引く（辞書は言語ごとに完結）。
    if (ascii && dicts.containsKey(AppLang.es)) langs.add(AppLang.es);
    if (ascii && dicts.containsKey(AppLang.pt)) langs.add(AppLang.pt);
    if (langs.isEmpty) return SafetyResult.ok;

    var worst = SafetyLevel.OK;
    var abuse = false;
    final categories = <String>{};
    for (final lang in langs) {
      final dict = dicts[lang];
      if (dict == null) continue;
      final r = _evaluate(text, lang, dict);
      if (r.level.index > worst.index) worst = r.level;
      if (r.abuseContext) abuse = true;
      categories.addAll(r.categories);
    }
    return SafetyResult(worst, abuse, categories);
  }

  /// その言語で自由入力を出してよいか（危機辞書がある言語だけ）。
  bool isFreeTextAllowed(AppLang? lang) => lang != null && dicts.containsKey(lang);

  SafetyResult _evaluate(String text, AppLang lang, CrisisLexicon dict) {
    final rep = _buildRepresentation(text, lang, dict.exclusions);
    final categories = <String>{};

    final directHit = _matches(rep, lang, dict.direct);
    final indirectHit = _matches(rep, lang, dict.indirect);
    final harmHit = _matches(rep, lang, dict.harm);
    if (directHit || indirectHit || harmHit) {
      if (directHit) categories.add('direct');
      if (indirectHit) categories.add('indirect');
      if (harmHit) categories.add('harm');
      return SafetyResult(SafetyLevel.CRISIS, false, categories);
    }

    if (_matches(rep, lang, dict.abuse)) {
      categories.add('abuse');
      return SafetyResult(SafetyLevel.CRISIS, true, categories);
    }

    var abuseContext = false;
    if (_matches(rep, lang, dict.harassment)) {
      categories.add('harassment');
      abuseContext = true;
    }

    if (_countMatches(rep, lang, dict.soft) >= 1) {
      categories.add('soft');
      return SafetyResult(SafetyLevel.CRISIS_SOFT, abuseContext, categories);
    }

    if (_countMatches(rep, lang, dict.caution) >= 2) {
      categories.add('caution');
      return SafetyResult(SafetyLevel.CRISIS_SOFT, abuseContext, categories);
    }

    return SafetyResult(SafetyLevel.OK, abuseContext, categories);
  }

  _Representation _buildRepresentation(String text, AppLang lang, List<String> exclusions) {
    if (lang == AppLang.ja) {
      var compact = TextNormalizer.jaCompact(text);
      for (final ex in exclusions) {
        final exCompact = TextNormalizer.jaCompact(ex);
        if (exCompact.isNotEmpty) compact = compact.replaceAll(exCompact, '');
      }
      return _Representation(compact, TextNormalizer.removeJaFillers(compact));
    }
    final tokens = TextNormalizer.enTokens(TextNormalizer.foldDiacritics(text))
        .map(TextNormalizer.stripApostrophes)
        .toList();
    var padded = ' ${tokens.join(' ')} ';
    for (final ex in exclusions) {
      final exNorm = TextNormalizer.stripApostrophes(
        TextNormalizer.normBase(TextNormalizer.foldDiacritics(ex)),
      );
      if (exNorm.isNotEmpty) padded = padded.replaceAll(' $exNorm ', ' ');
    }
    final remaining = padded.trim().split(' ').where((t) => t.isNotEmpty).toList();
    return _Representation(
      padded,
      ' ${TextNormalizer.removeEnFillers(remaining).join(' ')} ',
    );
  }

  bool _matches(_Representation rep, AppLang lang, List<String> terms) =>
      terms.any((t) => t.isNotEmpty && _containsTerm(rep, lang, t));

  int _countMatches(_Representation rep, AppLang lang, List<String> terms) =>
      terms.where((t) => t.isNotEmpty && _containsTerm(rep, lang, t)).length;

  /// 辞書語句が強調・つなぎ語を含む場合（「もう無理」「i just want to vanish」）は raw と、
  /// 含まない場合は入力側の強調語を除いた stripped と照合する。
  bool _containsTerm(_Representation rep, AppLang lang, String term) {
    if (lang == AppLang.ja) {
      final t = TextNormalizer.jaCompact(term);
      final tStripped = TextNormalizer.removeJaFillers(t);
      if (tStripped != t || tStripped.isEmpty) return rep.raw.contains(t);
      return rep.stripped.contains(t);
    }
    final t = TextNormalizer.stripApostrophes(
      TextNormalizer.normBase(TextNormalizer.foldDiacritics(term)),
    );
    final tTokens = t.split(' ').where((s) => s.isNotEmpty);
    final hasFiller = tTokens.any(TextNormalizer.enFillers.contains);
    return hasFiller ? rep.raw.contains(' $t ') : rep.stripped.contains(' $t ');
  }

  static bool _containsKana(String text) {
    for (final c in text.codeUnits) {
      if ((c >= 0x3040 && c <= 0x30ff) || (c >= 0x4e00 && c <= 0x9fff)) return true;
    }
    return false;
  }

  static bool _containsAscii(String text) {
    for (final c in text.codeUnits) {
      if ((c >= 0x61 && c <= 0x7a) || (c >= 0x41 && c <= 0x5a)) return true;
    }
    return false;
  }
}
