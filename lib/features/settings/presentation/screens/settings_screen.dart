import 'dart:io' show Platform;

import 'package:flutter/material.dart';
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
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: const ZeroAppBar(title: '設定'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account section
            _sectionTitle(context, 'アカウント'),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: 'ログイン状態: ${settings.isAnonymous ? "匿名" : "連携済み"}',
                    trailing: settings.isAnonymous
                        ? TextButton(
                            onPressed: () => _showLinkAccountSheet(context, ref),
                            child: const Text('アカウント連携'),
                          )
                        : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Sound section
            _sectionTitle(context, '音の設定'),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: '効果音',
                    trailing: Switch(
                      value: settings.soundEnabled,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setSoundEnabled(value);
                      },
                    ),
                  ),
                  SettingTile(
                    title: 'バイノーラル',
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
            _sectionTitle(context, '通知'),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: 'レポート通知',
                    trailing: Switch(
                      value: settings.reportNotification,
                      onChanged: (value) {
                        ref.read(settingsProvider.notifier).setReportNotification(value);
                      },
                    ),
                  ),
                  SettingTile(
                    title: 'リマインダー',
                    trailing: Text(
                      settings.reminderTime ?? '未設定',
                      style: AppTypography.body.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _parseTime(settings.reminderTime),
                        helpText: 'リマインダー時刻を選択',
                        cancelText: 'クリア',
                        confirmText: '設定',
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
            _sectionTitle(context, 'テーマ'),
            ZeroCard(
              child: Row(
                children: [
                  _themeChip(context, ref, 'ダーク', 'dark', settings.themeMode),
                  _themeChip(context, ref, 'ライト', 'light', settings.themeMode),
                  _themeChip(context, ref, '自動', 'system', settings.themeMode),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Other section
            _sectionTitle(context, 'その他'),
            ZeroCard(
              child: Column(
                children: [
                  SettingTile(
                    title: 'デモを見る',
                    onTap: () => context.push('/demo'),
                  ),
                  SettingTile(
                    title: 'プライバシーポリシー',
                    onTap: () => _showLegalSheet(
                      context,
                      'プライバシーポリシー',
                      _privacyPolicyText,
                    ),
                  ),
                  SettingTile(
                    title: '利用規約',
                    onTap: () => _showLegalSheet(
                      context,
                      '利用規約',
                      _termsText,
                    ),
                  ),
                  SettingTile(
                    title: settings.pauseMode ? 'お休みモード中' : '休む',
                    trailing: settings.pauseMode
                        ? const Icon(Icons.pause_circle, size: 20)
                        : null,
                    onTap: () => _showPauseDialog(context, ref, settings.pauseMode),
                  ),
                  SettingTile(
                    title: 'アカウント削除',
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
                'アカウント連携',
                style: AppTypography.heading.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'データを安全に保護するため、アカウントを連携してください。',
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
                    await _linkAccount(ref, messenger, LinkProvider.apple);
                  },
                  icon: const Icon(Icons.apple),
                  label: const Text('Appleで連携'),
                ),
              if (Platform.isIOS) const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  await _linkAccount(ref, messenger, LinkProvider.google);
                },
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('Googleで連携'),
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
  ) async {
    try {
      final auth = ref.read(authServiceProvider);
      if (provider == LinkProvider.apple) {
        await auth.linkWithApple();
      } else {
        await auth.linkWithGoogle();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('アカウントを連携しました')),
      );
    } catch (e) {
      final message = _linkErrorMessage(e);
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _linkErrorMessage(Object error) {
    if (error.toString().contains('credential-already-in-use')) {
      return 'このアカウントは既に別のユーザーに連携されています。';
    }
    if (error.toString().contains('provider-already-linked')) {
      return 'このプロバイダーは既に連携済みです。';
    }
    if (error.toString().contains('cancelled') ||
        error.toString().contains('canceled')) {
      return '連携がキャンセルされました。';
    }
    return 'アカウント連携に失敗しました。もう一度お試しください。';
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
    final messenger = ScaffoldMessenger.of(context);
    if (currentlyPaused) {
      // Resume from pause
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('お休みモードを解除'),
          content: const Text('通知やリマインダーを再開します。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setPauseMode(false);
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('お休みモードを解除しました')),
                );
              },
              child: const Text('再開する'),
            ),
          ],
        ),
      );
    } else {
      // Enter pause
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('お休みモード'),
          content: const Text(
            '通知やリマインダーを一時停止します。\nいつでも再開できます。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).setPauseMode(true);
                Navigator.pop(dialogContext);
                messenger.showSnackBar(
                  const SnackBar(content: Text('お休みモードを有効にしました')),
                );
              },
              child: const Text('休む'),
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('アカウント削除'),
        content: const Text(
          'すべてのデータが完全に削除されます。\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
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
                  SnackBar(content: Text('削除に失敗しました: $e')),
                );
              }
            },
            child: const Text('削除する'),
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
}

enum LinkProvider { apple, google }

const _privacyPolicyText = '''
Zero プライバシーポリシー

最終更新日: 2025年1月1日

1. 収集する情報
Zeroは以下の情報を収集します。
・音声録音データ（端末内にのみ保存）
・声の分析メトリクス（エネルギー、明瞭度、表現幅、テンポ）
・自己評価データ
・アプリ設定情報

2. データの保存
すべてのデータは端末のローカルストレージに保存されます。音声データおよび分析結果は外部サーバーに送信されません。

3. データの利用目的
収集したデータは、声の変化の可視化およびレポート生成の目的にのみ使用します。

4. データの共有
お客様のデータを第三者と共有することはありません。

5. データの削除
アプリの「アカウント削除」機能またはアプリのアンインストールにより、すべてのデータが削除されます。

6. お問い合わせ
本ポリシーに関するご質問は、アプリ内のフィードバック機能よりお問い合わせください。
''';

const _termsText = '''
Zero 利用規約

最終更新日: 2025年1月1日

1. サービスの概要
Zeroは、毎日の声の記録を通じて自己理解を深めるためのアプリケーションです。

2. 利用条件
・本アプリは個人利用を目的としています
・録音した音声の著作権はユーザーに帰属します
・アプリの不正利用や改変は禁止します

3. 免責事項
・本アプリは医療診断を目的としたものではありません
・声の分析結果はあくまで参考情報です
・データの損失について、開発者は責任を負いません

4. サービスの変更・終了
開発者は、事前の通知なくサービスの内容を変更、または終了する場合があります。

5. 準拠法
本規約は日本法に準拠します。
''';

