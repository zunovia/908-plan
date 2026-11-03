import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'release_notification_scheduler.dart';

/// Local notification scheduling for the daily reminder, the weekly
/// report notice and the release (手放す) check-ins.
///
/// All scheduling is done on the device with inexact alarms, so no exact-alarm
/// permission is required and nothing is sent to any server.
class NotificationService implements ReleaseNotificationSink {
  static const int reminderId = 1001;
  static const int weeklyReportId = 1002;

  /// Weekly report notice fires on Monday at 09:00 local time.
  static const int weeklyReportWeekday = DateTime.monday;
  static const int weeklyReportHour = 9;

  static const String _channelId = 'voxna_reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  bool get isInitialized => _initialized;

  /// Called with the route of a tapped notification while the app is running
  /// (only routes accepted by [routeFromPayload]).
  void Function(String route)? onRoute;

  /// Initializes time zone data and the platform plugin. Safe to call twice.
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fall back to the package default (UTC). Reminders still fire daily,
      // only at a shifted hour on devices where the zone cannot be resolved.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: handleResponse,
    );
    _initialized = true;
  }

  /// Forwards a tapped notification's route to [onRoute].
  void handleResponse(NotificationResponse response) {
    final route = routeFromPayload(response.payload);
    if (route != null) onRoute?.call(route);
  }

  /// Route of the notification that launched the app, if any.
  Future<String?> launchRoute() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return routeFromPayload(details.notificationResponse?.payload);
    } catch (_) {
      return null;
    }
  }

  static final RegExp _routePattern = RegExp(r'^/release(/[a-z]+)?$');

  /// Accepts only in-app release routes ('/release', '/release/write',
  /// '/release/quick', ...). Anything else (including the payload-less
  /// daily / weekly notifications) yields null.
  static String? routeFromPayload(String? payload) {
    if (payload == null) return null;
    return _routePattern.hasMatch(payload) ? payload : null;
  }

  /// Requests the Android 13+ notification permission.
  /// Returns true when granted (or not required on this OS version).
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Schedules (or re-schedules) the daily reminder at [hour]:[minute].
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(reminderId);
    await _plugin.zonedSchedule(
      reminderId,
      title,
      body,
      nextInstanceOfTime(hour, minute),
      _details(channelName: 'Voxna'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => _plugin.cancel(reminderId);

  /// Schedules the weekly report notice (Monday 09:00 local time).
  Future<void> scheduleWeeklyReport({
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(weeklyReportId);
    await _plugin.zonedSchedule(
      weeklyReportId,
      title,
      body,
      nextInstanceOfWeekday(weeklyReportWeekday, weeklyReportHour, 0),
      _details(channelName: 'Voxna'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancelWeeklyReport() => _plugin.cancel(weeklyReportId);

  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> scheduleRelease({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required String payload,
    required String channelName,
    required String channelDescription,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          ReleaseNotificationScheduler.channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  @override
  Future<void> cancelIds(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  NotificationDetails _details({required String channelName}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        channelName,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
      ),
    );
  }

  /// Parses an "HH:mm" string into (hour, minute). Returns null when invalid.
  static ({int hour, int minute})? parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  /// Next occurrence of [hour]:[minute] strictly after [now] (default: now).
  static tz.TZDateTime nextInstanceOfTime(
    int hour,
    int minute, {
    tz.TZDateTime? now,
  }) {
    final base = now ?? tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      base.location,
      base.year,
      base.month,
      base.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(base)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Next occurrence of [weekday] (DateTime.monday..sunday) at [hour]:[minute].
  static tz.TZDateTime nextInstanceOfWeekday(
    int weekday,
    int hour,
    int minute, {
    tz.TZDateTime? now,
  }) {
    var scheduled = nextInstanceOfTime(hour, minute, now: now);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
