import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../widgets/text_fade_in.dart';

class MechanismScreen extends StatelessWidget {
  const MechanismScreen({super.key});

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
                  '3/6',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.graphic_eq,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFadeIn(
                text: 'このアプリは\n声の「響き」を聴きます。\n\n'
                    '言葉の内容は\n分析しません。\n\n'
                    '声の高さ、テンポ、\n揺らぎ、沈黙——\n'
                    'そこにあなたの\nパターンが映ります。',
                style: AppTypography.philosophy,
              ),
              const Spacer(),
              ZeroButton(
                label: '次へ',
                onPressed: () => context.go('/onboarding/mic-permission'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
