// 手放す（release）機能のドメインモデル。Luckarise (Kotlin) の domain/model を移植。
// 純 Dart（package:flutter を import しない）。
// 列挙値の名前は JSON・保存値と同じ（Kotlin の enum 名そのまま）にするため大文字のまま。
// ignore_for_file: constant_identifier_names

/// 列挙値を名前から引く。見つからなければ null。
T? enumByName<T extends Enum>(List<T> values, String? name) {
  if (name == null) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// コンテンツの言語。ファイルが無い種類は en にフォールバックする（危機辞書だけは言語ごとに完結）。
/// Luckarise の en/ja/es に、Voxna の pt を加えたもの。
enum AppLang {
  en('en'),
  ja('ja'),
  es('es'),
  pt('pt');

  const AppLang(this.code);

  final String code;

  /// languageTag（例 "ja-JP", "en", "es_MX", "pt-BR"）から対応言語を解決する。対応外は null。
  static AppLang? fromTag(String? languageTag) {
    if (languageTag == null || languageTag.trim().isEmpty) return null;
    final primary = languageTag.split(RegExp('[-_]')).first.toLowerCase();
    for (final l in AppLang.values) {
      if (l.code == primary) return l;
    }
    return null;
  }
}

/// Voxna の表示言語設定（'system'|'ja'|'en'|'es'|'pt'）からコンテンツ言語を決める。
/// 'system' のときは端末の言語コード（例 "ja"）を使い、対応外なら en。
AppLang contentLangFor(String localeCode, String systemLanguageCode) {
  if (localeCode != 'system') {
    final explicit = AppLang.fromTag(localeCode);
    if (explicit != null) return explicit;
  }
  return AppLang.fromTag(systemLanguageCode) ?? AppLang.en;
}

/// 手放しカードの種類。
enum CardKind { WORDS4, WORDS1, IDK, PRE, CROSS, BREATH, WATER, NONE }

/// 12 の感情タグ。
enum EmotionTag {
  ANXIETY,
  IMPATIENCE,
  ANGER,
  SADNESS,
  LONELINESS,
  GUILT,
  SHAME,
  FEAR,
  FATIGUE,
  ENVY,
  CONFUSION,
  CALM;

  /// 同点時の優先順位（先頭ほど優先）。
  static const List<EmotionTag> priority = [
    IMPATIENCE,
    ANXIETY,
    FATIGUE,
    SADNESS,
    LONELINESS,
    ANGER,
    FEAR,
    GUILT,
    SHAME,
    ENVY,
    CONFUSION,
    CALM,
  ];
}

/// 再生リマインドの表示頻度。
enum ReplayMode { EVERY, ONCE_PER_SESSION, OFF }

/// 応答を生成した経路。Voxna は RULE（端末内のルール応答）のみ。
enum RouteId { RULE }

/// 入力の安全性判定レベル（ordinal の大小で重さを比べる）。
enum SafetyLevel {
  OK,

  /// 柔らかい注意喚起止まり。続行可。
  CRISIS_SOFT,

  /// 危機フロー（相談窓口）へ遷移する。
  CRISIS,
}

/// 場面タグ（カード選択用）。
enum Scene { WORK, COMMUTE, FAMILY, NIGHT, MORNING, ANY }

/// 実践セッションの種類。
enum SessionKind {
  WORDS4,
  WORDS1,
  IDK,
  PRE,
  CROSS,
  BREATH,
  WATER,

  /// 対話のみで実践を伴わないセッション（危機フロー等）。
  CHAT_ONLY,
}

/// 実践セッションのきっかけ。
enum SessionTrigger {
  /// 「手放す」ボタンなど手動。
  MANUAL,

  /// 今日の一枚・通知からの 15 秒のひと言。
  QUICK,

  /// 朝夕チェックインなど時刻の通知から。
  TIME,

  /// 「あとで手放す」（出来事）から。
  EVENT,

  /// ウェアラブル（将来・Voxna では未使用）。
  WEARABLE,
}

/// 反応の引き起こされ方。
enum TriggerKind {
  URGE,
  OTHER,
  SELF,
  RESP,
  FILTER,
  UNKNOWN,
}

/// 「手放すタイミング」のきっかけ。[timed] は時刻の通知と結びつくもの。
enum TriggerCue {
  BEFORE_SLEEP(true),
  ON_WAKING(true),
  BEFORE_MEETING(false),
  BEFORE_CLOSING_SCREEN(false),
  WHEN_IRRITATED(false),
  ON_COMMUTE(false);

  const TriggerCue(this.timed);

  final bool timed;

  static TriggerCue? fromName(String? name) => enumByName(TriggerCue.values, name);

  /// 改行区切りで保存した文字列を復元する（不明な名前は捨て、重複は 1 つに）。
  static List<TriggerCue> decode(String? raw) {
    final out = <TriggerCue>[];
    for (final part in (raw ?? '').split('\n')) {
      final cue = fromName(part.trim());
      if (cue != null && !out.contains(cue)) out.add(cue);
    }
    return out;
  }

  static String encode(List<TriggerCue> cues) {
    final seen = <TriggerCue>[];
    for (final c in cues) {
      if (!seen.contains(c)) seen.add(c);
    }
    return seen.map((c) => c.name).join('\n');
  }
}

/// 自動ループの速度。[intervalMillis] が null ならループしない。
enum LoopSpeed {
  OFF(null),
  SLOW(2500),
  NORMAL(1600),
  FAST(1000);

  const LoopSpeed(this.intervalMillis);

  final int? intervalMillis;

  /// 設定値 "off"/"slow"/"normal"/"fast" から。不明は OFF（Luckarise と同じ）。
  static LoopSpeed fromSetting(String value) {
    switch (value) {
      case 'slow':
        return LoopSpeed.SLOW;
      case 'normal':
        return LoopSpeed.NORMAL;
      case 'fast':
        return LoopSpeed.FAST;
      default:
        return LoopSpeed.OFF;
    }
  }

  String get settingValue => name.toLowerCase();
}

/// 日付境界・夜間判定。「今日」は端末ローカルの 0 時、夜間は 0〜5 時未満。
class TimeRules {
  const TimeRules._();

  static bool isNightHour(int hour) => hour >= 0 && hour < 5;

  /// 1970-01-01 からの日数（ローカル日付の年月日で数える）。
  static int epochDay(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// epochDay をローカル日付（0 時）の DateTime に戻す。
  static DateTime dateOfEpochDay(int epochDay) {
    final utc = DateTime.fromMillisecondsSinceEpoch(
      epochDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// epoch millis → ローカルの epochDay。
  static int epochDayOfMillis(int millis) =>
      epochDay(DateTime.fromMillisecondsSinceEpoch(millis));
}

/// "HH:mm" 形式の時刻文字列と時・分の相互変換。
class TimeText {
  const TimeText._();

  /// "HH:mm"（1 桁も可）を (hour, minute) に。形式が不正なら null。
  static ({int hour, int minute})? parse(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  /// (hour, minute) を "HH:mm" に。範囲外はクランプする。
  static String format(int hour, int minute) {
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

/// 「直近 N 件」の ID リストを更新する純関数群。
class RecentIds {
  const RecentIds._();

  static const int defaultMaxSize = 7;

  /// [existing] の末尾に [newId] を追加し、直近 [maxSize] 件だけを残す。既存の同一 ID は末尾に移動する。
  static List<String> push(
    List<String> existing,
    String newId, {
    int maxSize = defaultMaxSize,
  }) {
    if (newId.trim().isEmpty) return _takeLast(existing, maxSize);
    final without = existing.where((e) => e != newId).toList()..add(newId);
    return _takeLast(without, maxSize);
  }

  static String encode(List<String> ids) => ids.join(',');

  static List<String> decode(String? csv) {
    if (csv == null || csv.trim().isEmpty) return const [];
    return csv.split(',').where((s) => s.trim().isNotEmpty).toList();
  }

  static List<String> _takeLast(List<String> list, int n) =>
      list.length <= n ? List.of(list) : list.sublist(list.length - n);
}

/// 「手放す言葉」のユーザー編集値（最大 8 語・1 語 24 文字）。
class CustomWords {
  const CustomWords._();

  static const int maxWords = 8;
  static const int maxLength = 24;

  static List<String> normalize(List<String> words) => words
      .map((w) => _take(w.trim(), maxLength))
      .where((w) => w.isNotEmpty)
      .take(maxWords)
      .toList();

  static String encode(List<String> words) => normalize(words).join('\n');

  static List<String> decode(String? raw) =>
      (raw == null || raw.trim().isEmpty) ? const [] : normalize(raw.split('\n'));
}

String _take(String s, int n) => s.length <= n ? s : s.substring(0, n);
