import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../widgets/text_fade_in.dart';

class PhilosophyScreen extends StatelessWidget {
  const PhilosophyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentWarm =
        isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm;

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
                  '1/6',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const Spacer(),
              TextFadeIn(
                text: 'あなたには、\n自分では聴こえない\n声がある。\n\n'
                    'それが聴こえたとき、\n繰り返しは\n静かになる。',
                style: AppTypography.philosophy,
                highlightWords: ['声', '聴こえない', '静かになる'],
                highlightColor: accentWarm,
              ),
              const Spacer(),
              ZeroButton(
                label: '始める',
                onPressed: () => context.go('/onboarding/mechanism'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.push('/onboarding/metaphor'),
                child: Text(
                  'この言葉について',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
