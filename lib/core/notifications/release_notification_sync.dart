import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/history/providers/history_provider.dart';
import '../../features/release/data/release_db.dart';
import '../../features/release/domain/models.dart';
import '../../features/release/domain/release_settings.dart';
import '../../features/release/providers/release_providers.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../providers/notification_providers.dart';
import 'release_notification_scheduler.dart';

/// Where release notifications go. Defaults to the app's [NotificationService].
final releaseNotificationSinkProvider = Provider<ReleaseNotificationSink>((ref) {
  return ref.watch(notificationServiceProvider);
});

/// Time zone used for release notifications. Starts as the zone resolved by
/// NotificationService.init and is refreshed by
/// [ReleaseNotificationSync.refreshTimeZone] every time the app returns to the
/// foreground (so travelling users get reminders at the local hour).
final releaseNotificationZoneProvider = StateProvider<tz.Location>((ref) => tz.local);

/// Resolves the device's current time zone, or null when it cannot be resolved.
typedef ReleaseTimeZoneResolver = Future<tz.Location?> Function();

/// Asks the platform for the current time zone (FlutterTimezone). Never throws.
Future<tz.Location?> resolveDeviceTimeZone() async {
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    return tz.getLocation(name);
  } catch (_) {
    return null;
  }
}

/// How the current device time zone is resolved (tests override it).
final releaseTimeZoneResolverProvider =
    Provider<ReleaseTimeZoneResolver>((ref) => resolveDeviceTimeZone);

/// Keeps the release (手放す) notifications in step with the release settings,
/// the content language and today's release count.
///
/// main.dart reads [releaseNotificationSyncProvider] once (which starts the
/// listeners), calls [ReleaseNotificationSync.resync] at startup and
/// [ReleaseNotificationSync.attachLifecycle] so the window is rebuilt every
/// time the app comes back to the foreground.
class ReleaseNotificationSync {
  ReleaseNotificationSync(this._ref);

  final Ref _ref;
  Timer? _debounce;
  Future<void>? _running;
  bool _again = false;
  bool _disposed = false;
  AppLifecycleListener? _lifecycle;

  /// Number of completed reschedules (for tests / diagnostics).
  int runs = 0;

  /// True when a change between [a] and [b] changes what gets scheduled.
  static bool affectsSchedule(ReleaseSettings a, ReleaseSettings b) =>
      a.checkinMorningEnabled != b.checkinMorningEnabled ||
      a.checkinMorningTime != b.checkinMorningTime ||
      a.checkinEveningEnabled != b.checkinEveningEnabled ||
      a.checkinEveningTime != b.checkinEveningTime ||
      a.zeroDayEnabled != b.zeroDayEnabled ||
      a.zeroDayTime != b.zeroDayTime ||
      a.quietStart != b.quietStart ||
      a.quietEnd != b.quietEnd ||
      a.pauseUntil != b.pauseUntil ||
      a.triggerSentence != b.triggerSentence;

  /// Reschedules after a short pause (several quick changes → one run).
  void schedule({Duration delay = const Duration(milliseconds: 400)}) {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(resync()));
  }

  /// Rebuilds the release notification window now. Never throws.
  Future<void> resync() async {
    if (_disposed) return;
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final run = _run();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
    if (_again && !_disposed) {
      _again = false;
      await resync();
    }
  }

  Future<void> _run() async {
    try {
      await _ref.read(releaseRepositoryProvider).purgeAbandoned();
    } catch (_) {
      // Housekeeping only.
    }
    try {
      final settings = _ref.read(releaseSettingsProvider);
      final lang = _ref.read(releaseContentLangProvider);
      final file = await _ref.read(contentRepositoryProvider).notifications(lang);
      final l10n = await AppLocalizations.delegate.load(Locale(lang.code));
      if (_disposed) return;
      await ReleaseNotificationScheduler(_ref.read(releaseNotificationSinkProvider)).reschedule(
        settings: settings,
        now: _ref.read(releaseClockProvider)(),
        zone: _ref.read(releaseNotificationZoneProvider),
        todayCount: _ref.read(releaseRepositoryProvider).todayCount(),
        items: file?.items ?? const [],
        channelName: l10n.rel_vx_notif_channel_name,
        channelDescription: l10n.rel_vx_notif_channel_desc,
      );
      runs++;
    } catch (_) {
      // Notifications are best-effort; never surface scheduling failures.
    }
  }

  /// Cancels every release notification (account deletion).
  Future<void> cancelAll() async {
    try {
      await ReleaseNotificationScheduler(_ref.read(releaseNotificationSinkProvider)).cancelAll();
    } catch (_) {}
  }

  /// Re-resolves the device time zone (the user may have travelled while the
  /// app was in the background). Returns true when the zone changed.
  /// Failure-safe: when the zone cannot be resolved (error, null or no answer
  /// within [timeout]) the previous one is kept.
  Future<bool> refreshTimeZone({Duration timeout = const Duration(seconds: 3)}) async {
    if (_disposed) return false;
    try {
      final resolver = _ref.read(releaseTimeZoneResolverProvider);
      // Re-wrap so the timeout's null fits even when the resolver returns a
      // narrower Future (e.g. Future<Location>).
      Future<tz.Location?> resolve() async => await resolver();
      final next = await resolve().timeout(timeout, onTimeout: () => null);
      if (next == null || _disposed) return false;
      final zone = _ref.read(releaseNotificationZoneProvider.notifier);
      if (zone.state.name == next.name) return false;
      try {
        // Keep tz.local (daily / weekly reminders) in step as well.
        tz.setLocalLocation(next);
      } catch (_) {}
      zone.state = next;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Called when the app returns to the foreground: refresh the day-based
  /// providers, re-resolve the time zone, then rebuild the window.
  Future<void> onResume() async {
    refreshDayDependents();
    final zoneChanged = await refreshTimeZone();
    schedule();
    // The daily reminder (1001) and the weekly report (1002) were scheduled in
    // the old zone; move them to local time in the new one as well.
    if (zoneChanged && !_disposed) {
      try {
        await _ref.read(settingsProvider.notifier).resyncNotifications();
      } catch (_) {}
    }
  }

  /// Reschedules whenever the app returns to the foreground.
  void attachLifecycle() {
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(onResume()));
  }

  /// Providers computed from "today" only recompute when the data changes, so a
  /// day that rolls over while the app stays alive would keep showing
  /// yesterday's card / counts and a crisis banner past its 24 hours.
  void refreshDayDependents() {
    if (_disposed) return;
    try {
      _ref.invalidate(releaseTodayCardProvider);
      _ref.invalidate(releaseSummaryProvider);
      _ref.invalidate(releaseWeeklyStatsProvider);
      _ref.invalidate(releaseCrisisBannerProvider);
      _ref.invalidate(releaseCountsByMonthProvider);
      _ref.invalidate(historyReleaseCountsProvider);
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _lifecycle?.dispose();
  }
}

final releaseNotificationSyncProvider = Provider<ReleaseNotificationSync>((ref) {
  final sync = ReleaseNotificationSync(ref);
  ref.onDispose(sync.dispose);

  ref.listen<ReleaseSettings>(
    releaseSettingsProvider,
    (prev, next) {
      if (prev == null || ReleaseNotificationSync.affectsSchedule(prev, next)) sync.schedule();
    },
    onError: (_, __) {},
  );
  ref.listen<AppLang>(
    releaseContentLangProvider,
    (prev, next) {
      if (prev != next) sync.schedule();
    },
    onError: (_, __) {},
  );

  // After a session: today's zero-day reminder appears / disappears when
  // today's count crosses zero.
  // Skipped when the release storage could not be opened at start-up.
  if (Hive.isBoxOpen(ReleaseDb.sessionsBoxName)) {
    final repo = ref.watch(releaseRepositoryProvider);
    var releasedToday = repo.todayCount() > 0;
    final sub = repo.watch().listen((_) {
      final now = repo.todayCount() > 0;
      if (now != releasedToday) {
        releasedToday = now;
        sync.schedule();
      }
    });
    ref.onDispose(sub.cancel);
  }
  return sync;
});
