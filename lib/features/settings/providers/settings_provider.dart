import 'dart:ui';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/notification_providers.dart';
import '../../../core/providers/storage_providers.dart';
import '../../onboarding/providers/onboarding_provider.dart';

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
  @override
  SettingsState build() {
    final authState = ref.watch(authStateProvider);
    final isAnonymous = authState.valueOrNull?.isAnonymous ?? true;

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
  }

  /// Loads the localization for the current UI language (used for
  /// notification texts, which are rendered outside the widget tree).
  Future<AppLocalizations> _loadL10n() {
    final code = state.localeCode;
    final locale =
        code == 'system' ? PlatformDispatcher.instance.locale : Locale(code);
    return AppLocalizations.delegate.load(locale);
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

  Future<void> deleteAccountData() async {
    final db = ref.read(localDbProvider);
    final storage = ref.read(secureStorageProvider);
    final auth = ref.read(authServiceProvider);

    // Firebase first — if this fails, local data is preserved
    await auth.deleteAccount();
    try {
      await db.clearAll();
      await storage.deleteAll();
      await ref.read(voiceClipServiceProvider).deleteAll();
      await ref.read(notificationServiceProvider).cancelAll();
    } finally {
      ref.invalidate(onboardingCompleteProvider);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
