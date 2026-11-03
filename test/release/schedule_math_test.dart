import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_app/features/release/domain/schedule_math.dart';

void main() {
  tzdata.initializeTimeZones();
  final zone = tz.getLocation('Asia/Tokyo');

  int at(int y, int mo, int d, int h, int mi) => tz.TZDateTime(zone, y, mo, d, h, mi).millisecondsSinceEpoch;

  group('isQuiet (Kotlin ScheduleMathTest)', () {
    test('same day range', () {
      const start = ClockTime(9, 0);
      const end = ClockTime(17, 0);
      expect(ScheduleMath.isQuiet(const ClockTime(12, 0), start, end), isTrue);
      expect(ScheduleMath.isQuiet(const ClockTime(8, 59), start, end), isFalse);
      expect(ScheduleMath.isQuiet(const ClockTime(17, 0), start, end), isFalse);
    });

    test('day crossing range', () {
      const start = ClockTime(22, 0);
      const end = ClockTime(7, 0);
      expect(ScheduleMath.isQuiet(const ClockTime(23, 30), start, end), isTrue);
      expect(ScheduleMath.isQuiet(const ClockTime(0, 0), start, end), isTrue);
      expect(ScheduleMath.isQuiet(const ClockTime(6, 59), start, end), isTrue);
      expect(ScheduleMath.isQuiet(const ClockTime(7, 0), start, end), isFalse);
      expect(ScheduleMath.isQuiet(const ClockTime(21, 59), start, end), isFalse);
    });

    test('exact boundary start is inclusive', () {
      expect(ScheduleMath.isQuiet(const ClockTime(22, 0), const ClockTime(22, 0), const ClockTime(7, 0)), isTrue);
    });

    test('equal start and end means no quiet hours', () {
      const t = ClockTime(10, 0);
      expect(ScheduleMath.isQuiet(const ClockTime(10, 0), t, t), isFalse);
      expect(ScheduleMath.isQuiet(const ClockTime(23, 0), t, t), isFalse);
    });

    test('parseTime requires HH:mm', () {
      expect(ScheduleMath.parseTime('22:00'), const ClockTime(22, 0));
      expect(ScheduleMath.parseTime('7:00'), isNull);
      expect(ScheduleMath.parseTime('24:00'), isNull);
      expect(ScheduleMath.parseTime(null), isNull);
      expect(ScheduleMath.parseTime(''), isNull);
    });
  });

  group('nextFixed (Kotlin ScheduleMathTest)', () {
    test('picks later time today when not yet passed', () {
      expect(ScheduleMath.nextFixed(now: at(2026, 10, 13, 7, 0), hour: 8, minute: 0, zone: zone), at(2026, 10, 13, 8, 0));
    });

    test('rolls to next day when already passed', () {
      expect(ScheduleMath.nextFixed(now: at(2026, 10, 13, 9, 0), hour: 8, minute: 0, zone: zone), at(2026, 10, 14, 8, 0));
    });

    test('exactly at target time rolls to next day', () {
      expect(ScheduleMath.nextFixed(now: at(2026, 10, 13, 8, 0), hour: 8, minute: 0, zone: zone), at(2026, 10, 14, 8, 0));
    });

    test('candidate outside day crossing quiet hours stays', () {
      expect(
        ScheduleMath.nextFixed(
          now: at(2026, 10, 13, 20, 0),
          hour: 21,
          minute: 30,
          quietStart: '22:00',
          quietEnd: '07:00',
          zone: zone,
        ),
        at(2026, 10, 13, 21, 30),
      );
    });

    test('inside day crossing quiet hours is pushed to quiet end', () {
      expect(
        ScheduleMath.nextFixed(
          now: at(2026, 10, 13, 20, 0),
          hour: 23,
          minute: 0,
          quietStart: '22:00',
          quietEnd: '07:00',
          zone: zone,
        ),
        at(2026, 10, 14, 7, 0),
      );
    });

    test('respects pauseUntil beyond quiet hours', () {
      final pause = at(2026, 10, 20, 10, 0);
      expect(
        ScheduleMath.nextFixed(
          now: at(2026, 10, 13, 20, 0),
          hour: 8,
          minute: 0,
          quietStart: '22:00',
          quietEnd: '07:00',
          pauseUntil: pause,
          zone: zone,
        ),
        pause,
      );
    });

    test('pauseUntil landing inside quiet hours is pushed to quiet end', () {
      expect(
        ScheduleMath.nextFixed(
          now: at(2026, 10, 13, 20, 0),
          hour: 8,
          minute: 0,
          quietStart: '22:00',
          quietEnd: '07:00',
          pauseUntil: at(2026, 10, 20, 0, 0),
          zone: zone,
        ),
        at(2026, 10, 20, 7, 0),
      );
    });

    test('pauseUntil shorter than candidate keeps candidate', () {
      expect(
        ScheduleMath.nextFixed(
          now: at(2026, 10, 13, 20, 0),
          hour: 21,
          minute: 0,
          pauseUntil: at(2026, 10, 13, 20, 30),
          zone: zone,
        ),
        at(2026, 10, 13, 21, 0),
      );
    });

    test('works across DST spring-forward without throwing', () {
      final ny = tz.getLocation('America/New_York');
      final now = tz.TZDateTime(ny, 2026, 3, 8, 1, 0).millisecondsSinceEpoch;
      expect(ScheduleMath.nextFixed(now: now, hour: 2, minute: 30, zone: ny), greaterThan(now));
    });
  });

  group('nextBell (Kotlin ScheduleMathTest)', () {
    test('falls within min and max minutes when no quiet or pause', () {
      final now = at(2026, 10, 13, 10, 0);
      final random = Random(42);
      for (var i = 0; i < 50; i++) {
        final next = ScheduleMath.nextBell(now: now, random: random, minMinutes: 15, maxMinutes: 90, zone: zone);
        final delta = (next - now) ~/ 60000;
        expect(delta >= 15 && delta <= 90, isTrue, reason: 'delta $delta');
      }
    });

    test('equal min and max is deterministic', () {
      final now = at(2026, 10, 13, 10, 0);
      expect(
        ScheduleMath.nextBell(now: now, random: Random(1), minMinutes: 30, maxMinutes: 30, zone: zone),
        at(2026, 10, 13, 10, 30),
      );
    });

    test('pushed out of quiet hours', () {
      expect(
        ScheduleMath.nextBell(
          now: at(2026, 10, 13, 22, 50),
          random: Random(1),
          minMinutes: 30,
          maxMinutes: 30,
          quietStart: '22:00',
          quietEnd: '07:00',
          zone: zone,
        ),
        at(2026, 10, 14, 7, 0),
      );
    });

    test('respects pauseUntil', () {
      final pause = at(2026, 10, 15, 9, 0);
      expect(
        ScheduleMath.nextBell(
          now: at(2026, 10, 13, 10, 0),
          random: Random(1),
          minMinutes: 30,
          maxMinutes: 30,
          pauseUntil: pause,
          zone: zone,
        ),
        pause,
      );
    });

    test('swaps reversed min and max', () {
      final now = at(2026, 10, 13, 10, 0);
      final next = ScheduleMath.nextBell(now: now, random: Random(1), minMinutes: 90, maxMinutes: 15, zone: zone);
      final delta = (next - now) ~/ 60000;
      expect(delta >= 15 && delta <= 90, isTrue);
    });
  });

  group('plan / notification helpers', () {
    test('plan returns enabled reminders with fixed ids and slots', () {
      final now = at(2026, 10, 13, 6, 0);
      final plan = ScheduleMath.plan(
        now: now,
        zone: zone,
        morningEnabled: true,
        morningTime: '07:30',
        eveningEnabled: false,
        eveningTime: '21:00',
        zeroDayEnabled: true,
        zeroDayTime: '20:00',
        quietStart: '22:00',
        quietEnd: '07:00',
      );
      expect(plan.map((p) => p.notificationId), [2001, 2003]);
      expect(plan.map((p) => p.slot), ['MORNING', 'NIGHT']);
      expect(plan.first.atMillis, at(2026, 10, 13, 7, 30));
      expect(plan.last.atMillis, at(2026, 10, 13, 20, 0));
    });

    test('plan skips invalid times', () {
      final plan = ScheduleMath.plan(
        now: at(2026, 10, 13, 6, 0),
        zone: zone,
        morningEnabled: true,
        morningTime: 'bogus',
        eveningEnabled: true,
        eveningTime: '21:00',
        zeroDayEnabled: false,
        zeroDayTime: '20:00',
      );
      expect(plan.map((p) => p.reminderId), ['evening']);
    });

    test('javaStringHashCode matches Java', () {
      expect(ScheduleMath.javaStringHashCode(''), 0);
      expect(ScheduleMath.javaStringHashCode('morning'), 1240152004);
      expect(ScheduleMath.javaStringHashCode('zero_day'), 687218053);
      expect(ScheduleMath.javaStringHashCode('evening'), -1376511864);
    });

    test('notificationTextIndex is floorMod(epochDay + hashCode, size)', () {
      expect(ScheduleMath.notificationTextIndex(0, 'zero_day', 0), isNull);
      final idx = ScheduleMath.notificationTextIndex(20000, 'zero_day', 7)!;
      expect(idx, (20000 + (687218053)) % 7);
      expect(idx >= 0 && idx < 7, isTrue);
    });

    test('zero day reminder is skipped when already released today', () {
      expect(ScheduleMath.shouldSkipZeroDay('zero_day', 3), isTrue);
      expect(ScheduleMath.shouldSkipZeroDay('zero_day', 0), isFalse);
      expect(ScheduleMath.shouldSkipZeroDay('morning', 3), isFalse);
    });
  });
}
