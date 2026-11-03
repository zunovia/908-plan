import 'package:timezone/timezone.dart' as tz;

import '../../features/release/domain/content_models.dart';
import '../../features/release/domain/models.dart';
import '../../features/release/domain/release_settings.dart';
import '../../features/release/domain/schedule_math.dart';

/// Where release (手放す) notifications are delivered.
///
/// [NotificationService] implements it; tests use a fake.
abstract class ReleaseNotificationSink {
  /// Schedules one one-shot notification on the `voxna_release` channel.
  Future<void> scheduleRelease({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required String payload,
    required String channelName,
    required String channelDescription,
  });

  /// Cancels the given notification ids (unknown ids are ignored).
  Future<void> cancelIds(Iterable<int> ids);
}

/// One release notification to schedule.
class ReleaseNotificationPlan {
  const ReleaseNotificationPlan({
    required this.id,
    required this.reminderId,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;

  /// 'morning' / 'evening' / 'zero_day'.
  final String reminderId;
  final tz.TZDateTime at;
  final String title;
  final String body;

  /// Route opened when the notification is tapped.
  final String payload;
}

/// Turns the release settings into concrete one-shot notifications.
///
/// flutter_local_notifications cannot run Dart code when a notification
/// fires, so instead of Luckarise's "fire then reschedule one" we keep a
/// rolling window of [occurrencesPerReminder] upcoming one-shot notifications
/// per reminder. The window is rebuilt at app start, when the app returns to
/// the foreground, when the release settings change and after a release
/// session (so the zero-day reminder for today disappears once the user has
/// released something).
///
/// The window covers [occurrencesPerReminder] (28) days, so reminders keep
/// coming for four weeks even if the app is never opened.
///
/// IDs (all within 2001–2084, part of the 2000–2999 release range; 2100+ stays
/// reserved for trigger cues): `base + 3 * index` where base is 2001 (morning),
/// 2002 (evening), 2003 (zero day) and index is 0..[occurrencesPerReminder]-1.
/// The three bases interleave, so the ids are unique and together cover
/// 2001–2084 contiguously — which also includes every id of the former 7-day
/// layout (`base + 10 * index`, 2001–2063), so an upgrade cancels those too.
/// At most 84 release notifications are pending at once (far below Android's
/// ~500 alarm limit). Existing Voxna ids 1001/1002 are never touched here.
class ReleaseNotificationScheduler {
  ReleaseNotificationScheduler(this._sink);

  final ReleaseNotificationSink _sink;

  static const String channelId = 'voxna_release';

  /// Upcoming notifications kept per reminder (one per day → 28 days).
  static const int occurrencesPerReminder = 28;

  /// How many days ahead to look for occurrences (pause / quiet hours can
  /// collapse several days into one).
  static const int searchDays = 56;

  /// Id stride between two occurrences of the same reminder (one per base).
  static const int idStride = 3;

  /// Title used when the user has not written their own sentence.
  static const String fallbackTitle = 'Voxna';

  static const String routeQuick = '/release/quick';
  static const String routeWrite = '/release/write';

  static const List<int> _bases = [
    ScheduleMath.idMorning,
    ScheduleMath.idEvening,
    ScheduleMath.idZeroDay,
  ];

  /// Notification id for the [index]-th occurrence of [baseId].
  static int idFor(int baseId, int index) => baseId + idStride * index;

  /// Every id this scheduler may use.
  static List<int> get allIds => [
        for (final base in _bases)
          for (var i = 0; i < occurrencesPerReminder; i++) idFor(base, i),
      ];

  /// Route opened by a reminder: the morning card and the zero-day nudge go
  /// to the 15-second release, the evening check-in to the write screen.
  static String payloadFor(String reminderId) =>
      reminderId == ScheduleMath.reminderEvening ? routeWrite : routeQuick;

  /// Builds the notification list. Pure: no plugin calls.
  ///
  /// [todayCount] is the number of releases started today; when it is above
  /// zero, today's zero-day reminder is skipped.
  /// [items] are the notifications.json entries for the content language.
  static List<ReleaseNotificationPlan> buildPlan({
    required ReleaseSettings settings,
    required int now,
    required tz.Location zone,
    required int todayCount,
    required List<NotificationItem> items,
  }) {
    final sentence = settings.triggerSentence.trim();
    final title = sentence.isEmpty ? fallbackTitle : sentence;
    final nowZ = tz.TZDateTime.fromMillisecondsSinceEpoch(zone, now);
    final todayEpoch = TimeRules.epochDay(DateTime(nowZ.year, nowZ.month, nowZ.day));
    final out = <ReleaseNotificationPlan>[];

    void addReminder(bool enabled, String time, int baseId, String reminderId) {
      if (!enabled) return;
      final t = ScheduleMath.parseTime(time);
      if (t == null) return;
      final slot = ScheduleMath.slotFor(reminderId);
      final candidates = items.where((i) => i.slot == slot).toList();
      if (candidates.isEmpty) return;

      final seen = <int>{};
      var index = 0;
      for (var d = 0; d < searchDays && index < occurrencesPerReminder; d++) {
        // Nominal day of this occurrence (before quiet hours / pause shift it).
        final int base;
        final int nominalEpoch;
        if (d == 0) {
          base = now;
          final todayAt = tz.TZDateTime(zone, nowZ.year, nowZ.month, nowZ.day, t.hour, t.minute);
          nominalEpoch = todayAt.isAfter(nowZ) ? todayEpoch : todayEpoch + 1;
        } else {
          base = tz.TZDateTime(zone, nowZ.year, nowZ.month, nowZ.day + d)
                  .millisecondsSinceEpoch -
              1;
          nominalEpoch = todayEpoch + d;
        }
        if (nominalEpoch == todayEpoch &&
            ScheduleMath.shouldSkipZeroDay(reminderId, todayCount)) {
          continue;
        }
        final atMillis = ScheduleMath.nextFixed(
          now: base,
          hour: t.hour,
          minute: t.minute,
          quietStart: settings.quietStart,
          quietEnd: settings.quietEnd,
          pauseUntil: settings.pauseUntil,
          zone: zone,
        );
        if (atMillis <= now || !seen.add(atMillis)) continue;
        final at = tz.TZDateTime.fromMillisecondsSinceEpoch(zone, atMillis);
        final epochDay = TimeRules.epochDay(DateTime(at.year, at.month, at.day));
        final textIndex = ScheduleMath.notificationTextIndex(epochDay, reminderId, candidates.length)!;
        out.add(ReleaseNotificationPlan(
          id: idFor(baseId, index),
          reminderId: reminderId,
          at: at,
          title: title,
          body: candidates[textIndex].text,
          payload: payloadFor(reminderId),
        ));
        index++;
      }
    }

    addReminder(settings.checkinMorningEnabled, settings.checkinMorningTime, ScheduleMath.idMorning,
        ScheduleMath.reminderMorning);
    addReminder(settings.checkinEveningEnabled, settings.checkinEveningTime, ScheduleMath.idEvening,
        ScheduleMath.reminderEvening);
    addReminder(settings.zeroDayEnabled, settings.zeroDayTime, ScheduleMath.idZeroDay,
        ScheduleMath.reminderZeroDay);
    return out;
  }

  /// Cancels every release notification and schedules the current plan.
  /// Returns the scheduled plan.
  Future<List<ReleaseNotificationPlan>> reschedule({
    required ReleaseSettings settings,
    required int now,
    required tz.Location zone,
    required int todayCount,
    required List<NotificationItem> items,
    required String channelName,
    required String channelDescription,
  }) async {
    await cancelAll();
    final plan = buildPlan(
      settings: settings,
      now: now,
      zone: zone,
      todayCount: todayCount,
      items: items,
    );
    for (final p in plan) {
      await _sink.scheduleRelease(
        id: p.id,
        title: p.title,
        body: p.body,
        at: p.at,
        payload: p.payload,
        channelName: channelName,
        channelDescription: channelDescription,
      );
    }
    return plan;
  }

  /// Cancels every release notification (ids 2001–2084).
  Future<void> cancelAll() => _sink.cancelIds(allIds);
}
