import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_app/core/notifications/notification_service.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  final tokyo = tz.getLocation('Asia/Tokyo');

  group('NotificationService.parseTime', () {
    test('parses HH:mm', () {
      final t = NotificationService.parseTime('07:30');
      expect(t, isNotNull);
      expect(t!.hour, 7);
      expect(t.minute, 30);
    });

    test('rejects malformed or out-of-range values', () {
      expect(NotificationService.parseTime(null), isNull);
      expect(NotificationService.parseTime(''), isNull);
      expect(NotificationService.parseTime('7'), isNull);
      expect(NotificationService.parseTime('24:00'), isNull);
      expect(NotificationService.parseTime('12:60'), isNull);
      expect(NotificationService.parseTime('ab:cd'), isNull);
    });
  });

  group('NotificationService.nextInstanceOfTime', () {
    test('schedules later today when the time is still ahead', () {
      final now = tz.TZDateTime(tokyo, 2026, 10, 13, 8, 0);
      final next = NotificationService.nextInstanceOfTime(21, 0, now: now);
      expect(next, tz.TZDateTime(tokyo, 2026, 10, 13, 21, 0));
    });

    test('rolls to tomorrow when the time already passed', () {
      final now = tz.TZDateTime(tokyo, 2026, 10, 13, 22, 0);
      final next = NotificationService.nextInstanceOfTime(21, 0, now: now);
      expect(next, tz.TZDateTime(tokyo, 2026, 10, 14, 21, 0));
    });

    test('rolls to tomorrow when the time is exactly now', () {
      final now = tz.TZDateTime(tokyo, 2026, 10, 13, 21, 0);
      final next = NotificationService.nextInstanceOfTime(21, 0, now: now);
      expect(next, tz.TZDateTime(tokyo, 2026, 10, 14, 21, 0));
    });
  });

  group('NotificationService.nextInstanceOfWeekday', () {
    test('finds the coming Monday 09:00', () {
      // 2026-10-13 is a Tuesday
      final now = tz.TZDateTime(tokyo, 2026, 10, 13, 12, 0);
      final next = NotificationService.nextInstanceOfWeekday(
        DateTime.monday,
        9,
        0,
        now: now,
      );
      expect(next, tz.TZDateTime(tokyo, 2026, 10, 19, 9, 0));
      expect(next.weekday, DateTime.monday);
    });

    test('uses today when it is the right weekday and time is ahead', () {
      // 2026-10-19 is a Monday
      final now = tz.TZDateTime(tokyo, 2026, 10, 19, 7, 0);
      final next = NotificationService.nextInstanceOfWeekday(
        DateTime.monday,
        9,
        0,
        now: now,
      );
      expect(next, tz.TZDateTime(tokyo, 2026, 10, 19, 9, 0));
    });
  });
}
