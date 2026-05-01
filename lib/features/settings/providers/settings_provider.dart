import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/audio_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/storage_providers.dart';
import '../../onboarding/providers/onboarding_provider.dart';

class SettingsState {
  final bool isAnonymous;
  final bool soundEnabled;
  final bool binauralEnabled;
  final bool reportNotification;
  final String? reminderTime;
  final String themeMode; // 'dark', 'light', 'system'
  final bool pauseMode;

  const SettingsState({
    this.isAnonymous = true,
    this.soundEnabled = true,
    this.binauralEnabled = true,
    this.reportNotification = true,
    this.reminderTime,
    this.themeMode = 'system',
    this.pauseMode = false,
  });

  SettingsState copyWith({
    bool? isAnonymous,
    bool? soundEnabled,
    bool? binauralEnabled,
    bool? reportNotification,
    Object? reminderTime = _sentinel,
    String? themeMode,
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
    final pauseMode = await storage.getPauseMode();

    state = state.copyWith(
      soundEnabled: soundEnabled,
      binauralEnabled: binauralEnabled,
      reportNotification: reportNotification,
      reminderTime: reminderTime,
      themeMode: themeMode ?? 'system',
      pauseMode: pauseMode,
    );
    ref.read(soundManagerProvider).enabled = soundEnabled;
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
  }

  void setReminderTime(String? time) {
    state = state.copyWith(reminderTime: time);
    ref.read(secureStorageProvider).setReminderTime(time);
  }

  void setThemeMode(String mode) {
    state = state.copyWith(themeMode: mode);
    ref.read(secureStorageProvider).setThemeMode(mode);
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
    } finally {
      ref.invalidate(onboardingCompleteProvider);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
