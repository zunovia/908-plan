import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_app/core/notifications/notification_route.dart';
import 'package:zero_app/core/notifications/notification_service.dart';
import 'package:zero_app/core/notifications/release_notification_scheduler.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/release_settings.dart';
import 'package:zero_app/features/release/domain/schedule_math.dart';

import 'fakes/release_notification_fakes.dart';

const items = [
  NotificationItem('m1', 'MORNING', 'morning one'),
  NotificationItem('m2', 'MORNING', 'morning two'),
  NotificationItem('m3', 'MORNING', 'morning three'),
  NotificationItem('n1', 'NIGHT', 'night one'),
  NotificationItem('n2', 'NIGHT', 'night two'),
];

void main() {
  tzdata.initializeTimeZones();
  final tokyo = tz.getLocation('Asia/Tokyo');
  int at(int y, int m, int d, int h, [int min = 0]) =>
      tz.TZDateTime(tokyo, y, m, d, h, min).millisecondsSinceEpoch;

  // 2026-11-03 (Tue) 08:00 Tokyo.
  final now = at(2026, 11, 3, 8);

  List<ReleaseNotificationPlan> plan(ReleaseSettings s, {int todayCount = 0, int? nowMs}) =>
      ReleaseNotificationScheduler.buildPlan(
        settings: s,
        now: nowMs ?? now,
        zone: tokyo,
        todayCount: todayCount,
        items: items,
      );

  group('ReleaseNotificationScheduler.buildPlan', () {
    test('nothing is scheduled while every reminder is off', () {
      expect(plan(const ReleaseSettings()), isEmpty);
    });

    test('morning check-in: a rolling week of one-shot notifications', () {
      final p = plan(const ReleaseSettings(checkinMorningEnabled: true, checkinMorningTime: '07:30'));
      expect(p, hasLength(ReleaseNotificationScheduler.occurrencesPerReminder));
      // 07:30 already passed today → starts tomorrow.
      expect(p.first.at, tz.TZDateTime(tokyo, 2026, 11, 4, 7, 30));
      expect(p.last.at, tz.TZDateTime(tokyo, 2026, 11, 10, 7, 30));
      expect(p.map((e) => e.id), [2001, 2011, 2021, 2031, 2041, 2051, 2061]);
      expect(p.every((e) => e.payload == '/release/quick'), isTrue);
      expect(p.every((e) => e.title == 'Voxna'), isTrue);
      // Body: Luckarise's per-day pick among the MORNING texts.
      for (final e in p) {
        final day = DateTime(e.at.year, e.at.month, e.at.day);
        final epochDay = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;
        final idx = ScheduleMath.notificationTextIndex(epochDay, 'morning', 3)!;
        expect(e.body, ['morning one', 'morning two', 'morning three'][idx]);
      }
    });

    test('the user sentence becomes the title', () {
      final p = plan(const ReleaseSettings(
        checkinEveningEnabled: true,
        triggerSentence: '  寝る前に、ひと言手放す ',
      ));
      expect(p.first.title, '寝る前に、ひと言手放す');
      expect(p.first.payload, '/release/write');
      expect(p.first.id, ScheduleMath.idEvening);
      expect(p.first.at, tz.TZDateTime(tokyo, 2026, 11, 3, 21));
      expect(['night one', 'night two'], contains(p.first.body));
    });

    test('quiet hours move a reminder to the end of the quiet time', () {
      final p = plan(const ReleaseSettings(
        checkinEveningEnabled: true,
        checkinEveningTime: '23:00',
        quietStart: '22:00',
        quietEnd: '07:00',
      ));
      expect(p.first.at, tz.TZDateTime(tokyo, 2026, 11, 4, 7));
      expect(p.every((e) => e.at.hour == 7 && e.at.minute == 0), isTrue);
      expect(p.map((e) => e.at.millisecondsSinceEpoch).toSet(), hasLength(p.length));
    });

    test('a 1-week pause keeps everything after the pause, without duplicates', () {
      final pauseUntil = now + const Duration(days: 7).inMilliseconds;
      final p = plan(ReleaseSettings(
        checkinMorningEnabled: true,
        pauseUntil: pauseUntil,
        quietStart: '00:00',
        quietEnd: '00:00',
      ));
      expect(p, hasLength(ReleaseNotificationScheduler.occurrencesPerReminder));
      expect(p.every((e) => e.at.millisecondsSinceEpoch >= pauseUntil), isTrue);
      expect(p.map((e) => e.at.millisecondsSinceEpoch).toSet(), hasLength(p.length));
      // First one fires right when the pause ends, the next on the following morning.
      expect(p.first.at.millisecondsSinceEpoch, pauseUntil);
      expect(p[1].at, tz.TZDateTime(tokyo, 2026, 11, 11, 7, 30));
    });

    test('zero-day reminder is skipped today once something was released', () {
      const s = ReleaseSettings(zeroDayEnabled: true, zeroDayTime: '20:00');
      final none = plan(s, todayCount: 0);
      expect(none.first.at, tz.TZDateTime(tokyo, 2026, 11, 3, 20));
      expect(none.first.id, ScheduleMath.idZeroDay);
      expect(none.first.payload, '/release/quick');

      final released = plan(s, todayCount: 3);
      expect(released.first.at, tz.TZDateTime(tokyo, 2026, 11, 4, 20));
      expect(released, hasLength(ReleaseNotificationScheduler.occurrencesPerReminder));
    });

    test('invalid times and missing texts schedule nothing', () {
      expect(plan(const ReleaseSettings(checkinMorningEnabled: true, checkinMorningTime: '7:3')), isEmpty);
      final p = ReleaseNotificationScheduler.buildPlan(
        settings: const ReleaseSettings(checkinMorningEnabled: true),
        now: now,
        zone: tokyo,
        todayCount: 0,
        items: const [NotificationItem('n1', 'NIGHT', 'night')],
      );
      expect(p, isEmpty);
    });

    test('ids stay in the release range and never touch 1001 / 1002', () {
      final ids = ReleaseNotificationScheduler.allIds;
      expect(ids, hasLength(21));
      expect(ids.toSet(), hasLength(21));
      expect(ids.every((id) => id >= 2000 && id < 2100), isTrue);
      expect(ids, isNot(contains(NotificationService.reminderId)));
      expect(ids, isNot(contains(NotificationService.weeklyReportId)));
    });
  });

  group('ReleaseNotificationScheduler.reschedule', () {
    test('cancels every release id, then schedules the plan', () async {
      final sink = FakeSink();
      final result = await ReleaseNotificationScheduler(sink).reschedule(
        settings: const ReleaseSettings(checkinMorningEnabled: true, checkinEveningEnabled: true),
        now: now,
        zone: tokyo,
        todayCount: 0,
        items: items,
        channelName: '手放す',
        channelDescription: 'desc',
      );
      expect(sink.cancelled, ReleaseNotificationScheduler.allIds);
      expect(sink.scheduled, hasLength(14));
      expect(result, hasLength(14));
      expect(sink.scheduled.every((c) => c['channel'] == '手放す' && c['desc'] == 'desc'), isTrue);
    });
  });

  group('NotificationService (release)', () {
    test('scheduleRelease: voxna_release channel, inexact, one-shot, payload', () async {
      final plugin = FakePlugin();
      final service = NotificationService(plugin: plugin);
      await service.scheduleRelease(
        id: 2001,
        title: 'T',
        body: 'B',
        at: tz.TZDateTime(tokyo, 2026, 11, 4, 7, 30),
        payload: '/release/quick',
        channelName: '手放す',
        channelDescription: 'D',
      );
      final call = plugin.zoned.single;
      expect(call['id'], 2001);
      expect(call['payload'], '/release/quick');
      expect(call['mode'], AndroidScheduleMode.inexactAllowWhileIdle);
      expect(call['match'], isNull);
      final android = (call['details']! as NotificationDetails).android!;
      expect(android.channelId, 'voxna_release');
      expect(android.channelName, '手放す');
      expect(android.channelDescription, 'D');

      await service.cancelIds([2001, 2011]);
      expect(plugin.cancelled, [2001, 2011]);
    });

    test('only release routes are accepted from payloads', () {
      expect(NotificationService.routeFromPayload('/release/write'), '/release/write');
      expect(NotificationService.routeFromPayload('/release/quick'), '/release/quick');
      expect(NotificationService.routeFromPayload('/release'), '/release');
      expect(NotificationService.routeFromPayload(null), isNull);
      expect(NotificationService.routeFromPayload(''), isNull);
      expect(NotificationService.routeFromPayload('/settings'), isNull);
      expect(NotificationService.routeFromPayload('https://example.com'), isNull);
      expect(NotificationService.routeFromPayload('/release/../settings'), isNull);
    });

    test('a tapped notification forwards its route', () {
      final service = NotificationService(plugin: FakePlugin());
      final routes = <String>[];
      service.onRoute = routes.add;
      service.handleResponse(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/release/write',
      ));
      service.handleResponse(const NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
      ));
      expect(routes, ['/release/write']);
    });

    test('launch details give the route that opened the app', () async {
      final plugin = FakePlugin();
      final service = NotificationService(plugin: plugin);
      expect(await service.launchRoute(), isNull);
      plugin.launch = const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType: NotificationResponseType.selectedNotification,
          payload: '/release/quick',
        ),
      );
      expect(await service.launchRoute(), '/release/quick');
      plugin.launch = const NotificationAppLaunchDetails(false);
      expect(await service.launchRoute(), isNull);
    });
  });

  test('NotificationRouteDeduper drops the same route within the window', () {
    var t = DateTime(2026, 11, 3, 8);
    final d = NotificationRouteDeduper(clock: () => t);
    expect(d.accept('/release/write'), isTrue);
    expect(d.accept('/release/write'), isFalse);
    expect(d.accept('/release/quick'), isTrue);
    t = t.add(const Duration(seconds: 5));
    expect(d.accept('/release/quick'), isTrue);
  });
}
