// 入力テキストの正規化・照合。Luckarise の domain/text/TextNormalizer.kt を移植。純 Dart。
//
// Kotlin は java.text.Normalizer（NFKC / NFD）を使うが、Dart の標準には無いので、
// 照合に効く範囲（全角英数記号→半角、全角スペース、半角カナ→全角カナ、濁点・半濁点の結合、
// 三点リーダー等、ラテン文字の発音記号の分離）を自前で実装している。

class TextNormalizer {
  const TextNormalizer._();

  static const Set<int> _quoteChars = {0x2019, 0x2018, 0x60}; // ’ ‘ `
  static final RegExp _enTokenSplit = RegExp("[^a-z0-9']+");

  /// NFKC 相当の正規化 → 小文字化 → 引用符記号を ' に統一。
  static String normBase(String s) {
    final lower = nfkc(s).toLowerCase();
    final sb = StringBuffer();
    for (final c in lower.codeUnits) {
      sb.writeCharCode(_quoteChars.contains(c) ? 0x27 : c);
    }
    return sb.toString();
  }

  /// 日本語照合用: normBase 後に空白（全角スペース含む）を除いた文字列。
  static String jaCompact(String s) {
    final sb = StringBuffer();
    for (final c in normBase(s).codeUnits) {
      if (!isWhitespace(c) && c != 0x3000) sb.writeCharCode(c);
    }
    return sb.toString();
  }

  /// ラテン文字の発音記号を外す（á→a, ñ→n）。日本語（濁点）には使わない。
  static String foldDiacritics(String s) {
    final sb = StringBuffer();
    for (final c in s.codeUnits) {
      if (c >= 0x0300 && c <= 0x036f) continue; // 結合用の発音記号
      final mapped = _latinFold[c];
      if (mapped != null) {
        sb.write(mapped);
      } else {
        sb.writeCharCode(c);
      }
    }
    return sb.toString();
  }

  /// アポストロフィを除く（don't / dont の表記差を吸収）。
  static String stripApostrophes(String s) => s.replaceAll("'", '');

  /// 英語照合用: normBase 後に [^a-z0-9']+ で分割したトークン列。
  static List<String> enTokens(String s) =>
      normBase(s).split(_enTokenSplit).where((t) => t.isNotEmpty).toList();

  /// 危機辞書との照合前に取り除く「強調・つなぎ」語（英語）。
  static const Set<String> enFillers = {
    'just', 'really', 'so', 'honestly', 'truly', 'literally', 'totally', 'simply',
    'actually', 'seriously', 'basically', 'genuinely', 'completely', 'absolutely',
    'kinda', 'sorta', 'like', 'pretty', 'very', 'quite', 'rather', 'somewhat',
    'fucking', 'freaking', 'frickin', 'damn', 'bloody',
  };

  static List<String> removeEnFillers(List<String> tokens) =>
      tokens.where((t) => !enFillers.contains(t)).toList();

  /// 危機辞書との照合前に取り除く「強調・つなぎ」語（日本語）。長い語を先に置く。
  static const List<String> jaFillers = [
    '本当に', 'ほんとうに', 'ほんとに', 'ほんと', 'マジで', 'まじで', '正直', 'ぶっちゃけ',
    'もう', 'ただ', 'すごく', 'とても', 'めっちゃ', 'かなり', '本気で', '心から', 'いっそ',
  ];

  static String removeJaFillers(String compact) {
    var s = compact;
    for (final f in jaFillers) {
      s = s.replaceAll(f, '');
    }
    return s;
  }

  /// トークン列をスペース区切りで連結した中にフレーズが（語単位で）含まれるか。
  static bool enContainsPhrase(List<String> tokens, String phrase) {
    final padded = ' ${tokens.join(' ')} ';
    return padded.contains(' ${normBase(phrase)} ');
  }

  static bool enContainsPhraseText(String text, String phrase) =>
      enContainsPhrase(enTokens(text), phrase);

  /// Kotlin の Char.isWhitespace 相当。
  static bool isWhitespace(int c) =>
      (c >= 0x09 && c <= 0x0d) ||
      (c >= 0x1c && c <= 0x20) ||
      c == 0x85 ||
      c == 0xa0 ||
      c == 0x1680 ||
      (c >= 0x2000 && c <= 0x200a) ||
      c == 0x2028 ||
      c == 0x2029 ||
      c == 0x202f ||
      c == 0x205f ||
      c == 0x3000;

  // ---- NFKC（照合に必要な範囲） ----

  /// NFKC の部分実装。
  static String nfkc(String s) {
    final out = <int>[];
    final units = s.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final c = units[i];
      // 全角 ASCII（！〜～）→ 半角
      if (c >= 0xff01 && c <= 0xff5e) {
        out.add(c - 0xfee0);
        continue;
      }
      if (c == 0x3000 || c == 0xa0 || (c >= 0x2000 && c <= 0x200a) || c == 0x202f || c == 0x205f) {
        out.add(0x20);
        continue;
      }
      if (c == 0x2026) {
        out.addAll(const [0x2e, 0x2e, 0x2e]); // …
        continue;
      }
      if (c == 0x2025) {
        out.addAll(const [0x2e, 0x2e]); // ‥
        continue;
      }
      if (c == 0xffe5) {
        out.add(0xa5); // ￥
        continue;
      }
      // 半角カナ → 全角カナ（濁点・半濁点は直前と結合）
      if (c >= 0xff61 && c <= 0xff9f) {
        if (c == 0xff9e || c == 0xff9f) {
          final combined = out.isEmpty ? null : _composeMark(out.last, c == 0xff9e ? 0x3099 : 0x309a);
          if (combined != null) {
            out[out.length - 1] = combined;
          } else {
            out.add(c == 0xff9e ? 0x3099 : 0x309a);
          }
          continue;
        }
        out.add(_halfKana[c - 0xff61]);
        continue;
      }
      // 結合用の濁点・半濁点（NFD 由来）を直前のかなと結合
      if (c == 0x3099 || c == 0x309a) {
        final combined = out.isEmpty ? null : _composeMark(out.last, c);
        if (combined != null) {
          out[out.length - 1] = combined;
          continue;
        }
      }
      // ラテン文字 + 結合用発音記号（NFD 由来）を合成
      if (c >= 0x0300 && c <= 0x036f && out.isNotEmpty) {
        final composed = _latinCompose['${String.fromCharCode(out.last)}${String.fromCharCode(c)}'];
        if (composed != null) {
          out[out.length - 1] = composed;
          continue;
        }
      }
      out.add(c);
    }
    return String.fromCharCodes(out);
  }

  /// かな + 濁点(0x3099)/半濁点(0x309a) を 1 文字に。合成できなければ null。
  static int? _composeMark(int base, int mark) {
    if (mark == 0x3099) {
      if (base == 0x30a6) return 0x30f4; // ウ → ヴ
      if (base == 0x3046) return 0x3094; // う → ゔ
      if (base == 0x309d) return 0x309e;
      if (base == 0x30fd) return 0x30fe;
      if (_dakutenBases.contains(base)) return base + 1;
      if (base >= 0x30ef && base <= 0x30f2) return base + 8; // ワヰヱヲ → ヷヸヹヺ
      return null;
    }
    if (_handakutenBases.contains(base)) return base + 2;
    return null;
  }

  // か〜ど、は〜ほ（ひらがな・カタカナ）。濁音は +1。
  static final Set<int> _dakutenBases = {
    for (final b in const [0x304b, 0x30ab]) ...[
      for (var k = 0; k < 12; k += 2) b + k, // か き く け こ さ
      for (var k = 12; k < 24; k += 2) b + k, // し す せ そ た ち
      b + 25, b + 27, b + 29, // つ て と
      b + 36, b + 39, b + 42, b + 45, b + 48, // は ひ ふ へ ほ
    ],
  };

  // は〜ほ。半濁音は +2。
  static final Set<int> _handakutenBases = {
    for (final b in const [0x304b, 0x30ab]) ...[b + 36, b + 39, b + 42, b + 45, b + 48],
  };

  // U+FF61〜U+FF9F の半角カナに対応する全角文字。
  static const List<int> _halfKana = [
    0x3002, 0x300c, 0x300d, 0x3001, 0x30fb, 0x30f2, 0x30a1, 0x30a3, // ｡｢｣､･ｦｧｨ
    0x30a5, 0x30a7, 0x30a9, 0x30e3, 0x30e5, 0x30e7, 0x30c3, 0x30fc, // ｩｪｫｬｭｮｯｰ
    0x30a2, 0x30a4, 0x30a6, 0x30a8, 0x30aa, 0x30ab, 0x30ad, 0x30af, // ｱｲｳｴｵｶｷｸ
    0x30b1, 0x30b3, 0x30b5, 0x30b7, 0x30b9, 0x30bb, 0x30bd, 0x30bf, // ｹｺｻｼｽｾｿﾀ
    0x30c1, 0x30c4, 0x30c6, 0x30c8, 0x30ca, 0x30cb, 0x30cc, 0x30cd, // ﾁﾂﾃﾄﾅﾆﾇﾈ
    0x30ce, 0x30cf, 0x30d2, 0x30d5, 0x30d8, 0x30db, 0x30de, 0x30df, // ﾉﾊﾋﾌﾍﾎﾏﾐ
    0x30e0, 0x30e1, 0x30e2, 0x30e4, 0x30e6, 0x30e8, 0x30e9, 0x30ea, // ﾑﾒﾓﾔﾕﾖﾗﾘ
    0x30eb, 0x30ec, 0x30ed, 0x30ef, 0x30f3, 0x3099, 0x309a, // ﾙﾚﾛﾜﾝﾞﾟ
  ];

  // 発音記号つきラテン文字 → 基本文字（NFD して結合記号を落とすのと同じ結果）。
  static final Map<int, String> _latinFold = _buildLatinFold();

  // 基本文字 + 結合記号 → 合成済み文字（NFKC の合成）。
  static final Map<String, int> _latinCompose = _buildLatinCompose();

  static const Map<String, String> _foldSource = {
    'a': 'àáâãäåāăą',
    'A': 'ÀÁÂÃÄÅĀĂĄ',
    'c': 'çćĉċč',
    'C': 'ÇĆĈĊČ',
    'd': 'ď',
    'D': 'Ď',
    'e': 'èéêëēĕėęě',
    'E': 'ÈÉÊËĒĔĖĘĚ',
    'g': 'ĝğġģ',
    'G': 'ĜĞĠĢ',
    'h': 'ĥ',
    'H': 'Ĥ',
    'i': 'ìíîïĩīĭį',
    'I': 'ÌÍÎÏĨĪĬĮİ',
    'j': 'ĵ',
    'J': 'Ĵ',
    'k': 'ķ',
    'K': 'Ķ',
    'l': 'ĺļľ',
    'L': 'ĹĻĽ',
    'n': 'ñńņň',
    'N': 'ÑŃŅŇ',
    'o': 'òóôõöōŏő',
    'O': 'ÒÓÔÕÖŌŎŐ',
    'r': 'ŕŗř',
    'R': 'ŔŖŘ',
    's': 'śŝşš',
    'S': 'ŚŜŞŠ',
    't': 'ţť',
    'T': 'ŢŤ',
    'u': 'ùúûüũūŭůűų',
    'U': 'ÙÚÛÜŨŪŬŮŰŲ',
    'w': 'ŵ',
    'W': 'Ŵ',
    'y': 'ýÿŷ',
    'Y': 'ÝŸŶ',
    'z': 'źżž',
    'Z': 'ŹŻŽ',
  };

  static Map<int, String> _buildLatinFold() {
    final map = <int, String>{};
    _foldSource.forEach((base, accented) {
      for (final c in accented.codeUnits) {
        map[c] = base;
      }
    });
    return map;
  }

  // よく使う結合記号の合成（スペイン語・ポルトガル語・英語の範囲）。
  static Map<String, int> _buildLatinCompose() {
    const marks = {
      0x0300: 'àèìòùÀÈÌÒÙ', // grave
      0x0301: 'áéíóúýÁÉÍÓÚÝ', // acute
      0x0302: 'âêîôûÂÊÎÔÛ', // circumflex
      0x0303: 'ãñõÃÑÕ', // tilde
      0x0308: 'äëïöüÿÄËÏÖÜŸ', // diaeresis
      0x0327: 'çÇ', // cedilla
    };
    final out = <String, int>{};
    marks.forEach((mark, chars) {
      for (final c in chars.codeUnits) {
        final base = _latinFoldBase(c);
        if (base != null) out['$base${String.fromCharCode(mark)}'] = c;
      }
    });
    return out;
  }

  static String? _latinFoldBase(int c) {
    for (final e in _foldSource.entries) {
      if (e.value.codeUnits.contains(c)) return e.key;
    }
    return null;
  }
}
