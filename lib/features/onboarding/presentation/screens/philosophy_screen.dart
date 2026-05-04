import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
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
                  '1/5',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const Spacer(),
              TextFadeIn(
                text: l10n.onboarding_philosophy_text,
                style: AppTypography.philosophy,
                highlightWords: [l10n.onboarding_philosophy_highlight_voice, l10n.onboarding_philosophy_highlight_inaudible, l10n.onboarding_philosophy_highlight_quiet],
                highlightColor: accentWarm,
              ),
              const Spacer(),
              ZeroButton(
                label: l10n.common_start,
                onPressed: () => context.go('/onboarding/mechanism'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.push('/onboarding/metaphor'),
                child: Text(
                  l10n.onboarding_about_words,
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
