import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../widgets/text_fade_in.dart';

class MicPermissionScreen extends StatefulWidget {
  const MicPermissionScreen({super.key});

  @override
  State<MicPermissionScreen> createState() => _MicPermissionScreenState();
}

class _MicPermissionScreenState extends State<MicPermissionScreen> {
  bool _denied = false;

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      if (mounted) context.go('/onboarding/notification');
    } else {
      setState(() => _denied = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.topRight,
                child: Text(
                  '4/6',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.mic,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFadeIn(
                text: '声を聴くために\nマイクを使います。\n\n'
                    '録音データは\nサーバーに保存されません。\n'
                    '声から抽出された数値だけが\n残ります。\n\n'
                    '声そのものは、\nあなただけのものです。',
                style: AppTypography.philosophy,
              ),
              if (_denied) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'マイクの許可が必要です。',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('設定を開く'),
                ),
              ],
              const Spacer(),
              ZeroButton(
                label: '許可する',
                onPressed: _requestPermission,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
