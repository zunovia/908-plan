import 'dart:ui';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../../core/providers/audio_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/release_notification_sync.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/providers/storage_providers.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../release/data/release_db.dart';
import '../../release/providers/release_providers.dart';

class SettingsState {
  final bool isAnonymous;
  final bool soundEnabled;
  final bool binauralEnabled;
  final bool reportNotification;
  final String? reminderTime;
  final String themeMode; // 'dark', 'light', 'system'
  final String localeCode; // 'system', 'ja', 'en', 'es', 'pt'
  final bool pauseMode;

  const SettingsState({
    this.isAnonymous = true,
    this.soundEnabled = true,
    this.binauralEnabled = true,
    this.reportNotification = true,
    this.reminderTime,
    this.themeMode = 'system',
    this.localeCode = 'system',
    this.pauseMode = false,
  });

  SettingsState copyWith({
    bool? isAnonymous,
    bool? soundEnabled,
    bool? binauralEnabled,
    bool? reportNotification,
    Object? reminderTime = _sentinel,
    String? themeMode,
    String? localeCode,
    bool? pauseMode,
  }) {
    return SettingsState(
      isAnonymous: isAnonymous ?? this.isAnonymous,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      binauralEnabled: binauralEnabled ?? this.binauralEnabled,
      reportNotification: reportNotification ?? this.reportNotification,
      reminderTime: reminderTime == _sentinel
          ? this.reminderTime
          : reminderTime as String?,
      themeMode: themeMode ?? this.themeMode,
      localeCode: localeCode ?? this.localeCode,
      pauseMode: pauseMode ?? this.pauseMode,
    );
  }

  static const _sentinel = Object();
}

class SettingsNotifier extends Notifier<SettingsState> {
  /// True once the stored settings have been read (and the reminders synced).
  bool _loaded = false;

  @override
  SettingsState build() {
    final authState = ref.watch(authStateProvider);
    final isAnonymous = authState.valueOrNull?.isAnonymous ?? true;

    // build() also re-runs when the auth state changes and returns defaults
    // again, so the settings count as not loaded until the next load ends.
    _loaded = false;
    Future.microtask(_loadFromStorage);
    return SettingsState(isAnonymous: isAnonymous);
  }

  Future<void> _loadFromStorage() async {
    final storage = ref.read(secureStorageProvider);
    final soundEnabled = await storage.getSoundEnabled();
    final binauralEnabled = await storage.getBinauralEnabled();
    final reportNotification = await storage.getReportNotification();
    final reminderTime = await storage.getReminderTime();
    final themeMode = await storage.getThemeMode();
    final localeCode = await storage.getLocale();
    final pauseMode = await storage.getPauseMode();

    state = state.copyWith(
      soundEnabled: soundEnabled,
      binauralEnabled: binauralEnabled,
      reportNotification: reportNotification,
      reminderTime: reminderTime,
      themeMode: themeMode ?? 'system',
      localeCode: localeCode ?? 'system',
      pauseMode: pauseMode,
    );
    ref.read(soundManagerProvider).enabled = soundEnabled;

    // Re-sync scheduled notifications with the stored settings on every
    // start, so schedules survive app updates and setting changes.
    await _syncNotifications();
    _loaded = true;
  }

  /// Loads the localization for the current UI language (used for
  /// notification texts, which are rendered outside the widget tree).
  Future<AppLocalizations> _loadL10n() {
    final code = state.localeCode;
    final locale =
        code == 'system' ? PlatformDispatcher.instance.locale : Locale(code);
    return AppLocalizations.delegate.load(locale);
  }

  /// Reschedules the daily reminder and the weekly report (e.g. after the
  /// device time zone changed while the app was in the background).
  /// Before the stored settings are loaded this does nothing: the reminder
  /// time is not known yet, and loading syncs the reminders itself.
  Future<void> resyncNotifications() async {
    if (!_loaded) return;
    await _syncNotifications();
  }

  Future<void> _syncNotifications() async {
    final service = ref.read(notificationServiceProvider);
    try {
      final l10n = await _loadL10n();
      final time = NotificationService.parseTime(state.reminderTime);
      if (time != null) {
        await service.scheduleDailyReminder(
          hour: time.hour,
          minute: time.minute,
          title: l10n.notification_reminder_title,
          body: l10n.notification_reminder_body,
        );
      } else {
        await service.cancelDailyReminder();
      }
      if (state.reportNotification) {
        await service.scheduleWeeklyReport(
          title: l10n.notification_report_title,
          body: l10n.notification_report_body,
        );
      } else {
        await service.cancelWeeklyReport();
      }
    } catch (_) {
      // Notifications are best-effort; never surface scheduling failures.
    }
  }

  /// Asks for the notification permission (Android 13+). Returns false when
  /// the user declined, so the UI can explain how to enable it.
  Future<bool> requestNotificationPermission() {
    return ref.read(notificationServiceProvider).requestPermission();
  }

  void setSoundEnabled(bool value) {
    state = state.copyWith(soundEnabled: value);
    ref.read(secureStorageProvider).setSoundEnabled(value);
    ref.read(soundManagerProvider).enabled = value;
  }

  void setBinauralEnabled(bool value) {
    state = state.copyWith(binauralEnabled: value);
    ref.read(secureStorageProvider).setBinauralEnabled(value);
  }

  void setReportNotification(bool value) {
    state = state.copyWith(reportNotification: value);
    ref.read(secureStorageProvider).setReportNotification(value);
    _syncNotifications();
  }

  void setReminderTime(String? time) {
    state = state.copyWith(reminderTime: time);
    ref.read(secureStorageProvider).setReminderTime(time);
    _syncNotifications();
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(secureStorageProvider).setThemeMode(mode);
  }

  void setLocale(String code) {
    state = state.copyWith(localeCode: code);
    ref.read(secureStorageProvider).setLocale(code == 'system' ? null : code);
    // Notification texts follow the UI language.
    _syncNotifications();
  }

  void setPauseMode(bool value) {
    state = state.copyWith(pauseMode: value);
    ref.read(secureStorageProvider).setPauseMode(value);
  }

  /// Empties the 4 release boxes. If they could not be opened at start-up,
  /// the box files are deleted from disk instead, so nothing is left behind.
  Future<void> _clearReleaseData() async {
    try {
      await ref.read(releaseDbProvider).clearAll();
    } catch (_) {
      for (final name in const [
        ReleaseDb.sessionsBoxName,
        ReleaseDb.turnsBoxName,
        ReleaseDb.pendingBoxName,
        ReleaseDb.settingsBoxName,
      ]) {
        await Hive.deleteBoxFromDisk(name);
      }
    }
  }

  /// How long account deletion waits for Firebase to delete the user.
  static const Duration cloudDeleteTimeout = Duration(seconds: 10);

  /// How long the fallback sign-out may take after the cloud step failed.
  static const Duration cloudSignOutTimeout = Duration(seconds: 3);

  /// Deletes everything on the device, then the (anonymous) Firebase user.
  ///
  /// The device data goes first and unconditionally: Firebase holds only the
  /// anonymous UID, so a hanging or failing cloud call (no network,
  /// requires-recent-login, ...) must never keep the user's data on the
  /// device. Every local step runs even when an earlier one throws; the first
  /// local error is rethrown at the end, after the cloud step was attempted.
  ///
  /// When the Firebase user could not be deleted within [cloudTimeout], the
  /// app signs out (best-effort, at most [signOutTimeout]) so the next launch
  /// starts as a fresh anonymous user, and the result has
  /// `cloudDeleted: false`.
  Future<({bool cloudDeleted})> deleteAccountData({
    Duration cloudTimeout = cloudDeleteTimeout,
    Duration signOutTimeout = cloudSignOutTimeout,
  }) async {
    Object? firstError;
    StackTrace? firstStack;
    Future<void> step(Future<void> Function() run) async {
      try {
        await run();
      } catch (e, st) {
        firstError ??= e;
        firstStack ??= st;
      }
    }

    try {
      await step(() => ref.read(localDbProvider).clearAll());
      await step(() => ref.read(secureStorageProvider).deleteAll());
      await step(() => ref.read(voiceClipServiceProvider).deleteAll());
      // 手放す: records, chat turns, "later" queue and release settings.
      await step(_clearReleaseData);
      // Every scheduled notification: daily / weekly and release (2001–2063).
      await step(() => ref.read(notificationServiceProvider).cancelAll());
      try {
        await ref.read(releaseNotificationSyncProvider).cancelAll();
      } catch (_) {
        // Already covered by cancelAll above.
      }
    } finally {
      ref.invalidate(onboardingCompleteProvider);
      ref.invalidate(releaseSettingsProvider);
    }

    final cloudDeleted = await _deleteCloudAccount(
      cloudTimeout: cloudTimeout,
      signOutTimeout: signOutTimeout,
    );

    final error = firstError;
    if (error != null) Error.throwWithStackTrace(error, firstStack!);
    return (cloudDeleted: cloudDeleted);
  }

  /// Deletes the Firebase user; on timeout or error signs out instead and
  /// returns false. Never throws.
  Future<bool> _deleteCloudAccount({
    required Duration cloudTimeout,
    required Duration signOutTimeout,
  }) async {
    AuthService? auth;
    try {
      final service = ref.read(authServiceProvider);
      auth = service;
      await service.deleteAccount().timeout(cloudTimeout);
      return true;
    } catch (_) {
      try {
        await auth?.signOut().timeout(signOutTimeout);
      } catch (_) {
        // Best-effort: the device data is already gone.
      }
      return false;
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
