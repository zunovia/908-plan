// 手放しの画面で唱える「ツール」と、場面ごとの言葉の組。
// Luckarise 0.1.6 の feature/cleaning/ReleaseTools.kt と CleaningViewModel の言葉の決め方を移植。純 Dart。
// ignore_for_file: constant_identifier_names

import 'content_models.dart';
import 'models.dart';

export 'own_tools.dart';

/// ツールの選択肢。[id] は設定に保存する値:
/// "set"（いつもの手放す言葉の組）／"word:<words.json の id>"（その言葉だけ）／"own:<本文>"（自分でつくったもの）。
class ToolOption {
  const ToolOption(this.id, this.words, {this.own = false});

  final String id;
  final List<String> words;
  final bool own;

  /// 選択肢に出す文言（言葉の組なら " / " でつなぐ）。
  String get text => words.join(' / ');

  @override
  bool operator ==(Object other) =>
      other is ToolOption && other.id == id && other.own == own && _listEq(other.words, words);

  @override
  int get hashCode => Object.hash(id, own, Object.hashAll(words));
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class ReleaseTools {
  const ReleaseTools._();

  static const String set = 'set';
  static const String _wordPrefix = 'word:';
  static const String _ownPrefix = 'own:';

  static String wordId(String wordId) => '$_wordPrefix$wordId';
  static String ownId(String text) => '$_ownPrefix$text';

  /// 選択肢: 言葉の組 → 1 語ずつ（words.json の順）→ 自分でつくったもの。本文が空の語は出さない。
  /// [words] は words.json の (id, 本文)。
  static List<ToolOption> options(
    List<String> setWords,
    List<({String id, String text})> words,
    List<String> ownTools,
  ) {
    return [
      if (setWords.isNotEmpty) ToolOption(set, List.unmodifiable(setWords)),
      for (final w in words)
        if (w.text.trim().isNotEmpty) ToolOption(wordId(w.id), [w.text]),
      for (final t in ownTools) ToolOption(ownId(t), [t], own: true),
    ];
  }

  /// 保存されたツールが今も選べるならそれ、消えていれば "set"（それも無ければ null）。
  static ToolOption? resolve(String saved, List<ToolOption> options) {
    for (final o in options) {
      if (o.id == saved) return o;
    }
    for (final o in options) {
      if (o.id == set) return o;
    }
    return null;
  }
}

/// 手放しシーンの場面（ルートの mode 引数）。
enum ReleaseMode {
  WORDS4,
  WORDS1,
  IDK,
  CROSS,
  PRE;

  static ReleaseMode fromName(String? name) => enumByName(ReleaseMode.values, name) ?? ReleaseMode.WORDS4;

  /// ツールの選択が効く場面（手放す言葉・ひと言）。
  bool get toolsApply => this == ReleaseMode.WORDS4 || this == ReleaseMode.WORDS1;

  /// 保存するセッションの種類。
  SessionKind get sessionKind => enumByName(SessionKind.values, name) ?? SessionKind.WORDS4;
}

/// 手放しシーンで使う言葉の組（words.json とユーザー編集の「手放す言葉」から作る）。
class ReleaseWordSet {
  const ReleaseWordSet({
    required this.fourWords,
    required this.idkWord,
    required this.words1Pool,
    required this.idToText,
    required this.allWords,
  });

  /// ひと言（WORDS1）の候補順（idk を除く）。
  static const List<String> words1Order = [
    'thank_you', 'love', 'ice_blue', 'delete', 'like_so_much', 'sorry', 'forgive',
  ];

  /// 15 秒のひと言で唱える回数。
  static const int quickGoal = 3;

  /// × の場面で唱える記号。
  static const String crossMark = '×';

  /// いつもの手放す言葉の組（ユーザー編集があればそれ）。
  final List<String> fourWords;

  /// 「わからない」の言葉。
  final String idkWord;

  /// ひと言の候補（ユーザー編集があればそれ）。
  final List<String> words1Pool;
  final Map<String, String> idToText;

  /// words.json の (id, 本文) を並び順どおり。
  final List<({String id, String text})> allWords;

  factory ReleaseWordSet.build(WordsFile? words, List<String> customWords) {
    final idToText = {for (final i in words?.items ?? const <WordItem>[]) i.id: i.text};
    final all = [for (final i in words?.items ?? const <WordItem>[]) (id: i.id, text: i.text)];
    final four = customWords.isNotEmpty
        ? List<String>.of(customWords)
        : (words == null ? <String>[] : words.idsToText(words.four));
    final idk = words?.textFor('idk') ?? (four.isEmpty ? '' : four.first);
    List<String> pool;
    if (customWords.isNotEmpty) {
      pool = List<String>.of(customWords);
    } else {
      pool = words == null
          ? <String>[]
          : words.idsToText(words1Order.where((id) => words.textFor(id) != null).toList());
      if (pool.isEmpty) pool = four;
    }
    return ReleaseWordSet(
      fourWords: four,
      idkWord: idk,
      words1Pool: pool,
      idToText: idToText,
      allWords: all,
    );
  }

  /// その場面の「いつもの組」（ツール = set のとき）。
  List<String> setWordsFor(ReleaseMode mode) => mode == ReleaseMode.WORDS1 ? words1Pool : fourWords;

  /// ツールの選択肢。IDK / PRE / CROSS は元の言葉のままなので空。
  List<ToolOption> toolOptions(ReleaseMode mode, List<String> ownTools) =>
      mode.toolsApply ? ReleaseTools.options(setWordsFor(mode), allWords, ownTools) : const [];

  /// 場面の元の言葉（ツールを考えない）。PRE はカードの words（words.json の id）を本文に。
  List<String> baseWordsFor(ReleaseMode mode, {CardItem? card}) {
    switch (mode) {
      case ReleaseMode.IDK:
        return [idkWord];
      case ReleaseMode.CROSS:
        return const [crossMark];
      case ReleaseMode.PRE:
        final cw = card?.words ?? const <String>[];
        return cw.isNotEmpty ? cw.map((id) => idToText[id] ?? id).toList() : fourWords;
      case ReleaseMode.WORDS1:
        return words1Pool;
      case ReleaseMode.WORDS4:
        return fourWords;
    }
  }

  /// 保存されたツールを反映した、最初に出す言葉と選択中ツールの id（ツールが効かない場面は ''）。
  ({List<String> words, String selectedTool, List<ToolOption> tools}) initial(
    ReleaseMode mode, {
    required String savedTool,
    required List<String> ownTools,
    CardItem? card,
  }) {
    final tools = toolOptions(mode, ownTools);
    final tool = mode.toolsApply ? ReleaseTools.resolve(savedTool, tools) : null;
    final words = (tool != null && tool.id != ReleaseTools.set) ? tool.words : baseWordsFor(mode, card: card);
    return (words: words, selectedTool: tool?.id ?? '', tools: tools);
  }

  /// ツールを選んだときに出す言葉（set なら場面のいつもの組）。
  List<String> wordsForTool(ReleaseMode mode, ToolOption tool) =>
      tool.id == ReleaseTools.set ? setWordsFor(mode) : tool.words;
}
