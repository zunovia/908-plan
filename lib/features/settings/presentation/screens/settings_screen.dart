import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../widgets/setting_tile.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: ZeroAppBar(title: l10n.settings_title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account section
            _sectionTitle(context, l10n.settings_account),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: settings.isAnonymous ? l10n.settings_login_anonymous : l10n.settings_login_linked,
                    trailing: settings.isAnonymous
                        ? TextButton(
                            onPressed: () => _showLinkAccountSheet(context, ref),
                            child: Text(l10n.settings_link_account),
                          )
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Sound section
            _sectionTitle(context, l10n.settings_sound),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: l10n.settings_sound_effects,
                    trailing: Switch(
                      value: settings.soundEnabled,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setSoundEnabled(value);
                      },
                    ),
                  ),
                  SettingTile(
                    title: l10n.settings_binaural,
                    trailing: Switch(
                      value: settings.binauralEnabled,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setBinauralEnabled(value);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Notification section
            _sectionTitle(context, l10n.settings_notification),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: l10n.settings_report_notification,
                    trailing: Switch(
                      value: settings.reportNotification,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setReportNotification(value);
                      },
                    ),
                  ),
                  SettingTile(
                    title: l10n.settings_reminder,
                    trailing: Text(
                      settings.reminderTime ?? l10n.settings_not_set,
                      style: AppTypography.body.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _parseTime(settings.reminderTime),
                        helpText: l10n.settings_reminder_help,
                        cancelText: l10n.settings_reminder_clear,
                        confirmText: l10n.settings_reminder_set,
                      );
                      if (!context.mounted) return;
                      if (picked != null) {
                        final formatted =
                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                        ref.read(settingsProvider.notifier).setReminderTime(formatted);
                      } else {
                        ref.read(settingsProvider.notifier).setReminderTime(null);
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Theme section
            _sectionTitle(context, l10n.settings_theme),
            ZeroCard(
              child: Row(
                children: [
                  _themeChip(context, ref, l10n.settings_theme_dark, 'dark', settings.themeMode),
                  _themeChip(context, ref, l10n.settings_theme_light, 'light', settings.themeMode),
                  _themeChip(context, ref, l10n.settings_theme_auto, 'system', settings.themeMode),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Language section
            _sectionTitle(context, l10n.settings_language),
            ZeroCard(
              child: Wrap(
                runSpacing: AppSpacing.xs,
                children: [
                  _languageChip(context, ref, l10n.settings_lang_system, 'system', settings.localeCode),
                  _languageChip(context, ref, l10n.settings_lang_ja, 'ja', settings.localeCode),
                  _languageChip(context, ref, l10n.settings_lang_en, 'en', settings.localeCode),
                  _languageChip(context, ref, l10n.settings_lang_es, 'es', settings.localeCode),
                  _languageChip(context, ref, l10n.settings_lang_pt, 'pt', settings.localeCode),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Other section
            _sectionTitle(context, l10n.settings_other),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: l10n.settings_view_demo,
                    onTap: () => context.push('/demo'),
                  ),
                  SettingTile(
                    title: l10n.settings_privacy_policy,
                    onTap: () => _showLegalSheet(
                      context,
                      l10n.privacy_title,
                      l10n.privacy_body,
                    ),
                  ),
                  SettingTile(
                    title: l10n.settings_terms,
                    onTap: () => _showLegalSheet(
                      context,
                      l10n.terms_title,
                      l10n.terms_body,
                    ),
                  ),
                  SettingTile(
                    title: settings.pauseMode ? l10n.settings_pause_active : l10n.settings_pause,
                    trailing: settings.pauseMode
                        ? const Icon(Icons.pause_circle, size: 20)
                        : null,
                    onTap: () => _showPauseDialog(context, ref, settings.pauseMode),
                  ),
                  SettingTile(
                    title: l10n.settings_delete_account,
                    titleColor: Colors.red,
                    onTap: () => _showDeleteDialog(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String? time) {
    if (time == null) return const TimeOfDay(hour: 21, minute: 0);
    final parts = time.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 21, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 21,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  void _showLinkAccountSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.link_title,
                style: AppTypography.heading.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.link_description,
                style: AppTypography.body.copyWith(
                  color: Theme.of(sheetContext)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (Platform.isIOS)
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _linkAccount(ref, messenger, LinkProvider.apple, l10n);
                  },
                  icon: const Icon(Icons.apple),
                  label: Text(l10n.link_apple),
                ),
              if (Platform.isIOS) const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _linkAccount(ref, messenger, LinkProvider.google, l10n);
                },
                icon: const Icon(Icons.g_mobiledata),
                label: Text(l10n.link_google),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _linkAccount(
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    LinkProvider provider,
    AppLocalizations l10n,
  ) async {
    try {
      final auth = ref.read(authServiceProvider);
      if (provider == LinkProvider.apple) {
        await auth.linkWithApple();
      } else {
        await auth.linkWithGoogle();
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.link_success)),
      );
    } catch (e) {
      final message = _linkErrorMessage(e, l10n);
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _linkErrorMessage(Object error, AppLocalizations l10n) {
    if (error.toString().contains('credential-already-in-use')) {
      return l10n.link_error_already_used;
    }
    if (error.toString().contains('provider-already-linked')) {
      return l10n.link_error_already_linked;
    }
    if (error.toString().contains('cancelled') ||
        error.toString().contains('canceled')) {
      return l10n.link_error_cancelled;
    }
    return l10n.link_error_generic;
  }

  void _showLegalSheet(BuildContext context, String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTypography.heading.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    body,
                    style: AppTypography.body.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPauseDialog(BuildContext context, WidgetRef ref, bool currentlyPaused) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (currentlyPaused) {
      // Resume from pause
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.pause_resume_title),
          content: Text(l10n.pause_resume_description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setPauseMode(false);
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.pause_resumed)),
                );
              },
              child: Text(l10n.pause_resume_button),
            ),
          ],
        ),
      );
    } else {
      // Enter pause
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.pause_title),
          content: Text(l10n.pause_description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.common_cancel),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setPauseMode(true);
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.pause_activated)),
                );
              },
              child: Text(l10n.pause_button),
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.delete_title),
        content: Text(l10n.delete_description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(settingsProvider.notifier).deleteAccountData();
                if (!context.mounted) return;
                context.go('/');
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.delete_failed(e.toString()))),
                );
              }
            },
            child: Text(l10n.delete_button),
          ),
        ],
      ),
    );
  }

  Widget _themeChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String currentMode,
  ) {
    final isSelected = value == currentMode;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) {
            ref.read(settingsProvider.notifier).setThemeMode(value);
          },
        ),
      ),
    );
  }

  Widget _languageChip(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String currentLocale,
  ) {
    final isSelected = value == currentLocale;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          ref.read(settingsProvider.notifier).setLocale(value);
        },
      ),
    );
  }
}

enum LinkProvider { apple, google }
