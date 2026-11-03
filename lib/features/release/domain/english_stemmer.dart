// 簡易英語ステマー。Luckarise の domain/text/EnglishStemmer.kt を移植。純 Dart。
// 感情語辞書の照合用。危機語の照合には使わない（SafetyGate は normBase のみで照合する）。

class EnglishStemmer {
  const EnglishStemmer._();

  static const List<String> _suffixOrder = ['ies', 'ied', 'ing', 'ed', 'es', 's', 'ly'];
  static const String _vowels = 'aeiou';

  /// 語尾を除去して基本形に近づける。3 文字未満になる場合は除去しない。
  static String stem(String word) {
    for (final suf in _suffixOrder) {
      if (word.length > suf.length && word.endsWith(suf)) {
        final String base;
        if (suf == 'ies' || suf == 'ied') {
          base = '${word.substring(0, word.length - 3)}y';
        } else {
          base = word.substring(0, word.length - suf.length);
        }
        if (base.length < 3) return word;
        return (suf == 'ing' || suf == 'ed') ? _reduceDoubleConsonant(base) : base;
      }
    }
    return word;
  }

  /// 複数語からなる辞書語を空白区切りでステムする。
  static List<String> stemPhrase(String phrase) =>
      phrase.split(' ').where((w) => w.isNotEmpty).map(stem).toList();

  static String _reduceDoubleConsonant(String s) {
    if (s.length < 2) return s;
    final last = s[s.length - 1];
    final secondLast = s[s.length - 2];
    if (last == secondLast && !_vowels.contains(last)) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }
}
