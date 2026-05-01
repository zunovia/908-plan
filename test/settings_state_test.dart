import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/settings/providers/settings_provider.dart';

void main() {
  group('SettingsState', () {
    test('default values', () {
      const state = SettingsState();
      expect(state.isAnonymous, isTrue);
      expect(state.soundEnabled, isTrue);
      expect(state.binauralEnabled, isTrue);
      expect(state.reportNotification, isTrue);
      expect(state.reminderTime, isNull);
      expect(state.themeMode, 'system');
      expect(state.pauseMode, isFalse);
    });

    test('copyWith preserves all fields when no args given', () {
      final state = SettingsState(
        isAnonymous: false,
        soundEnabled: false,
        binauralEnabled: false,
        reportNotification: false,
        reminderTime: '08:00',
        themeMode: 'dark',
        pauseMode: true,
      );

      final copied = state.copyWith();

      expect(copied.isAnonymous, isFalse);
      expect(copied.soundEnabled, isFalse);
      expect(copied.binauralEnabled, isFalse);
      expect(copied.reportNotification, isFalse);
      expect(copied.reminderTime, '08:00');
      expect(copied.themeMode, 'dark');
      expect(copied.pauseMode, isTrue);
    });

    test('copyWith overrides specific fields', () {
      const state = SettingsState();
      final updated = state.copyWith(
        soundEnabled: false,
        themeMode: 'light',
      );

      expect(updated.soundEnabled, isFalse);
      expect(updated.themeMode, 'light');
      // Unchanged fields
      expect(updated.isAnonymous, isTrue);
      expect(updated.binauralEnabled, isTrue);
      expect(updated.reminderTime, isNull);
      expect(updated.pauseMode, isFalse);
    });

    group('sentinel pattern for reminderTime', () {
      test('preserves existing reminderTime when not passed', () {
        final state = SettingsState(reminderTime: '09:30');
        final copied = state.copyWith(soundEnabled: false);
        expect(copied.reminderTime, '09:30');
      });

      test('sets reminderTime to a new value', () {
        const state = SettingsState();
        final updated = state.copyWith(reminderTime: '21:00');
        expect(updated.reminderTime, '21:00');
      });

      test('clears reminderTime to null explicitly', () {
        final state = SettingsState(reminderTime: '09:30');
        final cleared = state.copyWith(reminderTime: null);
        expect(cleared.reminderTime, isNull);
      });
    });

    test('pauseMode can be toggled', () {
      const state = SettingsState(pauseMode: false);
      final paused = state.copyWith(pauseMode: true);
      expect(paused.pauseMode, isTrue);

      final unpaused = paused.copyWith(pauseMode: false);
      expect(unpaused.pauseMode, isFalse);
    });
  });
}
