// 「今日の一枚」の選び方。Luckarise の domain/today/TodayPick.kt を移植。純 Dart。
// 日付（epochDay）で決める純関数なので、手放すタブ・通知が同じ語・同じ一文を出せる。

import 'content_models.dart';
import 'models.dart';

class TodayPick {
  const TodayPick._();

  /// 語と一文は別の周期で回す（同じ組み合わせが続かないよう一文側に足す）。
  static const int lineSalt = 7;

  /// [epochDay] に対応する要素。空なら null。負の日でも floorMod で正しく回る。
  static T? pick<T>(List<T> items, int epochDay, {int salt = 0}) {
    if (items.isEmpty) return null;
    return items[(epochDay + salt) % items.length];
  }

  /// 今日の一枚（語 + 一文）。語は「手放す言葉」（ユーザー編集があればそれ、無ければ words.json の four）。
  static TodayCard card({
    required WordsFile? words,
    required List<String> customWords,
    required TodayFile? today,
    required DateTime date,
  }) {
    final epochDay = TimeRules.epochDay(date);
    final pool = customWords.isNotEmpty
        ? customWords
        : (words == null ? const <String>[] : words.idsToText(words.four));
    final word = pick(pool, epochDay) ?? '';
    final lines = today?.items.map((i) => i.text).toList() ?? const <String>[];
    return TodayCard(word: word, line: pick(lines, epochDay, salt: lineSalt));
  }
}

/// 今日の一枚の中身。
class TodayCard {
  const TodayCard({required this.word, this.line});

  /// 今日の語（空文字のことがある）。
  final String word;

  /// 今日の一文（today.json）。
  final String? line;
}
