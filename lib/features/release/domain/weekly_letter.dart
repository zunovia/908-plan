// 「今週の手紙」・7 日の点灯・今月の回数・おかえり・節目。Luckarise の WeeklyLetter.kt を移植。純 Dart。
// 回数の事実だけを扱い、評価や効能の判断は含めない。日付は年月日だけを見る（時刻は無視）。

import 'models.dart';

/// 1 回の実践の要約（日付と記憶チップ）。
class PracticeMark {
  const PracticeMark(this.day, [this.tags = const []]);

  /// 実践した日（ローカル日付。時刻は無視）。
  final DateTime day;
  final List<String> tags;

  int get epochDay => TimeRules.epochDay(day);
}

/// 「今週の手紙」に入れる事実。文章化は UI 側（l10n）。
class WeeklyStats {
  const WeeklyStats({
    required this.weekStart,
    required this.thisWeekCount,
    required this.lastWeekCount,
    required this.topTag,
    required this.topTagCount,
    required this.restDays,
  });

  /// 今週の月曜（ローカル 0 時）。
  final DateTime weekStart;
  final int thisWeekCount;
  final int lastWeekCount;
  final String? topTag;
  final int topTagCount;

  /// 今週、実践が 1 回もなかった曜日（今日より前の日だけ）。値は DateTime.monday(1)〜DateTime.sunday(7)。
  final List<int> restDays;
}

class WeeklyLetter {
  const WeeklyLetter._();

  static const Set<int> _milestones = {7, 30, 100, 365};

  /// [today] を含む週の月曜（ローカル 0 時）。
  static DateTime weekStartOf(DateTime today) =>
      TimeRules.dateOfEpochDay(TimeRules.epochDay(today) - (today.weekday - 1));

  static WeeklyStats stats(List<PracticeMark> marks, DateTime today) {
    final todayDay = TimeRules.epochDay(today);
    final start = todayDay - (today.weekday - 1);
    final end = start + 6;
    final lastStart = start - 7;
    final thisWeek = marks.where((m) => m.epochDay >= start && m.epochDay <= end).toList();
    final lastWeekCount = marks.where((m) => m.epochDay >= lastStart && m.epochDay < start).length;

    final counts = <String, int>{};
    for (final m in thisWeek) {
      for (final t in m.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    // Kotlin: maxWith(compareBy { value }.thenByDescending { key }) — 同数ならキーの小さい方。
    String? topTag;
    var topCount = 0;
    counts.forEach((k, v) {
      if (topTag == null || v > topCount || (v == topCount && k.compareTo(topTag!) < 0)) {
        topTag = k;
        topCount = v;
      }
    });

    final practiced = thisWeek.map((m) => m.epochDay).toSet();
    final rest = <int>[];
    for (var d = start; d < todayDay; d++) {
      if (!practiced.contains(d)) rest.add(TimeRules.dateOfEpochDay(d).weekday);
    }
    return WeeklyStats(
      weekStart: TimeRules.dateOfEpochDay(start),
      thisWeekCount: thisWeek.length,
      lastWeekCount: lastWeekCount,
      topTag: topTag,
      topTagCount: topTag == null ? 0 : topCount,
      restDays: rest,
    );
  }

  /// 最近 7 日（古い順、最後が今日）の実践有無。
  static List<bool> last7(List<PracticeMark> marks, DateTime today) {
    final days = marks.map((m) => m.epochDay).toSet();
    final t = TimeRules.epochDay(today);
    return [for (var offset = 6; offset >= 0; offset--) days.contains(t - offset)];
  }

  /// 今月の回数。
  static int monthCount(List<PracticeMark> marks, DateTime today) =>
      marks.where((m) => m.day.year == today.year && m.day.month == today.month).length;

  /// 3 日以上空いた後の最初の実践日か（「おかえり」）。今日まだ実践していなければ false。
  static bool isWelcomeBack(List<PracticeMark> marks, DateTime today, {int gapDays = 3}) {
    final days = marks.map((m) => m.epochDay).toSet();
    final t = TimeRules.epochDay(today);
    if (!days.contains(t)) return false;
    final previous = days.where((d) => d < t);
    if (previous.isEmpty) return false;
    final prev = previous.reduce((a, b) => a > b ? a : b);
    return t - prev >= gapDays;
  }

  /// 節目の回数（7・30・100・365）。溶ける演出を少し長くするために使う。
  static bool isMilestone(int count) => _milestones.contains(count);
}
