// Fakes for the release notification tests (no platform channel).

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:zero_app/core/notifications/release_notification_scheduler.dart';

/// Records the calls the release scheduler makes.
class FakeSink implements ReleaseNotificationSink {
  final List<Map<String, Object?>> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleRelease({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required String payload,
    required String channelName,
    required String channelDescription,
  }) async {
    scheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'at': at,
      'payload': payload,
      'channel': channelName,
      'desc': channelDescription,
    });
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async => cancelled.addAll(ids);
}

/// Stand-in for the platform plugin (only what NotificationService uses).
class FakePlugin implements FlutterLocalNotificationsPlugin {
  final List<Map<String, Object?>> zoned = [];
  final List<int> cancelled = [];
  NotificationAppLaunchDetails? launch;

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    zoned.add({
      'id': id,
      'title': title,
      'body': body,
      'at': scheduledDate,
      'details': notificationDetails,
      'mode': androidScheduleMode,
      'payload': payload,
      'match': matchDateTimeComponents,
    });
  }

  @override
  Future<void> cancel(int id, {String? tag}) async => cancelled.add(id);

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async => launch;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
