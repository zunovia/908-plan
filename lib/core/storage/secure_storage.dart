import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyThemeMode = 'theme_mode';
  static const _keySoundEnabled = 'sound_enabled';
  static const _keyBinauralEnabled = 'binaural_enabled';
  static const _keyReportNotification = 'report_notification';
  static const _keyReminderTime = 'reminder_time';
  static const _keyPauseMode = 'pause_mode';
  static const _keyLocale = 'locale';

  Future<void> setOnboardingComplete(bool value) =>
      _storage.write(key: _keyOnboardingComplete, value: value.toString());

  Future<bool> getOnboardingComplete() async {
    final value = await _storage.read(key: _keyOnboardingComplete);
    return value == 'true';
  }

  Future<void> setThemeMode(String mode) =>
      _storage.write(key: _keyThemeMode, value: mode);

  Future<String?> getThemeMode() => _storage.read(key: _keyThemeMode);

  Future<void> setSoundEnabled(bool value) =>
      _storage.write(key: _keySoundEnabled, value: value.toString());

  Future<bool> getSoundEnabled() async {
    final value = await _storage.read(key: _keySoundEnabled);
    return value != 'false'; // default true
  }

  Future<void> setBinauralEnabled(bool value) =>
      _storage.write(key: _keyBinauralEnabled, value: value.toString());

  Future<bool> getBinauralEnabled() async {
    final value = await _storage.read(key: _keyBinauralEnabled);
    return value != 'false'; // default true
  }

  Future<void> setReportNotification(bool value) =>
      _storage.write(key: _keyReportNotification, value: value.toString());

  Future<bool> getReportNotification() async {
    final value = await _storage.read(key: _keyReportNotification);
    return value != 'false'; // default true
  }

  Future<void> setReminderTime(String? time) async {
    if (time == null) {
      await _storage.delete(key: _keyReminderTime);
    } else {
      await _storage.write(key: _keyReminderTime, value: time);
    }
  }

  Future<String?> getReminderTime() => _storage.read(key: _keyReminderTime);

  Future<void> setPauseMode(bool value) =>
      _storage.write(key: _keyPauseMode, value: value.toString());

  Future<bool> getPauseMode() async {
    final value = await _storage.read(key: _keyPauseMode);
    return value == 'true'; // default false
  }

  Future<void> setLocale(String? locale) async {
    if (locale == null) {
      await _storage.delete(key: _keyLocale);
    } else {
      await _storage.write(key: _keyLocale, value: locale);
    }
  }

  Future<String?> getLocale() => _storage.read(key: _keyLocale);

  Future<void> deleteAll() => _storage.deleteAll();
}
