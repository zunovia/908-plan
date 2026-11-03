// 通知時刻の計算（静音時間・お休み・朝夕・0 回の日）。Luckarise の platform/notify/ScheduleMath.kt を移植。
// 純 Dart（package:timezone）。副作用は持たない。

import 'dart:math';

import 'package:timezone/timezone.dart' as tz;

/// 1 日の中の時刻（ミリ秒精度）。LocalTime の代わり。
class ClockTime implements Comparable<ClockTime> {
  const ClockTime(this.hour, this.minute, [this.second = 0, this.millisecond = 0]);

  ClockTime.fromDateTime(DateTime dt) : this(dt.hour, dt.minute, dt.second, dt.millisecond);

  final int hour;
  final int minute;
  final int second;
  final int millisecond;

  int get millisOfDay => ((hour * 60 + minute) * 60 + second) * 1000 + millisecond;

  @override
  int compareTo(ClockTime other) => millisOfDay.compareTo(other.millisOfDay);

  bool operator <(ClockTime o) => millisOfDay < o.millisOfDay;
  bool operator >=(ClockTime o) => millisOfDay >= o.millisOfDay;

  @override
  bool operator ==(Object other) => other is ClockTime && other.millisOfDay == millisOfDay;

  @override
  int get hashCode => millisOfDay.hashCode;

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// 予約する 1 件（手放す系の通知）。
class PlannedReminder {
  const PlannedReminder({
    required this.notificationId,
    required this.reminderId,
    required this.slot,
    required this.atMillis,
  });

  /// 通知 ID（2001 朝 / 2002 夕 / 2003 0 回の日）。
  final int notificationId;

  /// "morning" / "evening" / "zero_day"（Luckarise の ReminderRepository の id と同じ）。
  final String reminderId;

  /// notifications.json の slot（MORNING / NIGHT）。
  final String slot;
  final int atMillis;
}

class ScheduleMath {
  const ScheduleMath._();

  static const int idMorning = 2001;
  static const int idEvening = 2002;
  static const int idZeroDay = 2003;

  /// 「手放すタイミング」（きっかけ）用に予約できる ID の先頭（2100〜）。
  static const int idTriggerBase = 2100;

  static const String reminderMorning = 'morning';
  static const String reminderEvening = 'evening';
  static const String reminderZeroDay = 'zero_day';

  static final RegExp _timePattern = RegExp(r'^(\d{2}):(\d{2})(?::(\d{2}))?$');

  /// "HH:mm"（または "HH:mm:ss"）を解析する。解析できなければ null（LocalTime.parse と同じく 2 桁必須）。
  static ClockTime? parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final m = _timePattern.firstMatch(value);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    final s = m.group(3) == null ? 0 : int.parse(m.group(3)!);
    if (h > 23 || mi > 59 || s > 59) return null;
    return ClockTime(h, mi, s);
  }

  /// [time] が [start]〜[end] の静音時間帯か。start==end は「静音なし」。start>end は日跨ぎ。半開区間 [start, end)。
  static bool isQuiet(ClockTime time, ClockTime start, ClockTime end) {
    if (start == end) return false;
    if (start < end) return time >= start && time < end;
    return time >= start || time < end;
  }

  /// 固定時刻（朝・夕・0 回の日）の次回発火（epoch millis）。
  /// [now] より後で最も近い [hour]:[minute]。静音帯なら静音終了直後へ、[pauseUntil] より前なら [pauseUntil] 以降へずらす。
  static int nextFixed({
    required int now,
    required int hour,
    required int minute,
    String? quietStart,
    String? quietEnd,
    int pauseUntil = 0,
    required tz.Location zone,
  }) {
    final nowZ = tz.TZDateTime.fromMillisecondsSinceEpoch(zone, now);
    var candidate = tz.TZDateTime(zone, nowZ.year, nowZ.month, nowZ.day, hour, minute);
    if (!candidate.isAfter(nowZ)) {
      candidate = tz.TZDateTime(zone, nowZ.year, nowZ.month, nowZ.day + 1, hour, minute);
    }
    return _adjust(candidate, parseTime(quietStart), parseTime(quietEnd), pauseUntil, zone)
        .millisecondsSinceEpoch;
  }

  /// ランダム・ベルの次回発火（[minMinutes]〜[maxMinutes] 分後。逆順なら入れ替える）。Voxna では未使用だが互換のため残す。
  static int nextBell({
    required int now,
    required Random random,
    required int minMinutes,
    required int maxMinutes,
    String? quietStart,
    String? quietEnd,
    int pauseUntil = 0,
    required tz.Location zone,
  }) {
    final lo = max(min(minMinutes, maxMinutes), 1);
    final hi = max(max(minMinutes, maxMinutes), lo);
    final delta = hi == lo ? lo : lo + random.nextInt(hi - lo + 1);
    final candidate = tz.TZDateTime.fromMillisecondsSinceEpoch(zone, now + delta * 60000);
    return _adjust(candidate, parseTime(quietStart), parseTime(quietEnd), pauseUntil, zone)
        .millisecondsSinceEpoch;
  }

  /// 朝・夕・0 回の日の予約一覧（有効なものだけ）。時刻文字列が不正なものは飛ばす。
  static List<PlannedReminder> plan({
    required int now,
    required tz.Location zone,
    required bool morningEnabled,
    required String morningTime,
    required bool eveningEnabled,
    required String eveningTime,
    required bool zeroDayEnabled,
    required String zeroDayTime,
    String? quietStart,
    String? quietEnd,
    int pauseUntil = 0,
  }) {
    final out = <PlannedReminder>[];
    void add(bool enabled, String time, int id, String reminderId, String slot) {
      if (!enabled) return;
      final t = parseTime(time);
      if (t == null) return;
      out.add(PlannedReminder(
        notificationId: id,
        reminderId: reminderId,
        slot: slot,
        atMillis: nextFixed(
          now: now,
          hour: t.hour,
          minute: t.minute,
          quietStart: quietStart,
          quietEnd: quietEnd,
          pauseUntil: pauseUntil,
          zone: zone,
        ),
      ));
    }

    add(morningEnabled, morningTime, idMorning, reminderMorning, slotFor(reminderMorning)!);
    add(eveningEnabled, eveningTime, idEvening, reminderEvening, slotFor(reminderEvening)!);
    add(zeroDayEnabled, zeroDayTime, idZeroDay, reminderZeroDay, slotFor(reminderZeroDay)!);
    return out;
  }

  /// 通知文の区分（Luckarise の AlarmReceiver.slotFor と同じ。0 回の日は NIGHT）。
  static String? slotFor(String reminderId) {
    switch (reminderId) {
      case reminderMorning:
        return 'MORNING';
      case reminderEvening:
        return 'NIGHT';
      case reminderZeroDay:
        return 'NIGHT';
      default:
        return null;
    }
  }

  /// その日の通知文の添字。Luckarise と同じく floorMod(epochDay + reminderId.hashCode(), size)
  /// （hashCode は Java の String.hashCode）。size が 0 なら null。
  static int? notificationTextIndex(int epochDay, String reminderId, int size) {
    if (size <= 0) return null;
    return (epochDay + javaStringHashCode(reminderId)) % size;
  }

  /// 「まだ 0 回の日」は、今日すでに手放していれば鳴らさない。
  static bool shouldSkipZeroDay(String reminderId, int todayCount) =>
      reminderId == reminderZeroDay && todayCount > 0;

  /// Java の String.hashCode（32 bit 符号付き）。
  static int javaStringHashCode(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (31 * h + c) & 0xffffffff;
    }
    return h >= 0x80000000 ? h - 0x100000000 : h;
  }

  /// [dt] が静音帯なら静音が終わる直後（同日または翌日の [end]）。静音でなければ null。
  static tz.TZDateTime? _quietEndAfter(tz.TZDateTime dt, ClockTime start, ClockTime end, tz.Location zone) {
    if (!isQuiet(ClockTime.fromDateTime(dt), start, end)) return null;
    var candidate = tz.TZDateTime(zone, dt.year, dt.month, dt.day, end.hour, end.minute, end.second);
    if (!candidate.isAfter(dt)) {
      candidate = tz.TZDateTime(zone, dt.year, dt.month, dt.day + 1, end.hour, end.minute, end.second);
    }
    return candidate;
  }

  /// 静音帯・[pauseUntil] の両方を適用した、鳴らしてよい最初の時刻。
  static tz.TZDateTime _adjust(
    tz.TZDateTime dt,
    ClockTime? quietStart,
    ClockTime? quietEnd,
    int pauseUntil,
    tz.Location zone,
  ) {
    var result = dt;
    if (pauseUntil > 0) {
      final pauseAt = tz.TZDateTime.fromMillisecondsSinceEpoch(zone, pauseUntil);
      if (result.isBefore(pauseAt)) result = pauseAt;
    }
    if (quietStart != null && quietEnd != null) {
      final q = _quietEndAfter(result, quietStart, quietEnd, zone);
      if (q != null) result = q;
      if (pauseUntil > 0) {
        final pauseAt = tz.TZDateTime.fromMillisecondsSinceEpoch(zone, pauseUntil);
        if (result.isBefore(pauseAt)) result = pauseAt;
      }
    }
    return result;
  }
}
