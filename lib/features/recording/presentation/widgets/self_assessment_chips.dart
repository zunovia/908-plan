import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_colors.dart';

enum SelfAssessment {
  calm,
  normal,
  shaky,
  unknown;

  String label(AppLocalizations l10n) => switch (this) {
    calm => l10n.assessment_calm,
    normal => l10n.assessment_normal,
    shaky => l10n.assessment_shaky,
    unknown => l10n.assessment_unknown,
  };
}

class SelfAssessmentChips extends StatelessWidget {
  final ValueChanged<SelfAssessment> onSelected;
  final VoidCallback onSkip;

  const SelfAssessmentChips({
    super.key,
    required this.onSelected,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.assessment_question,
            style: AppTypography.philosophy.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: SelfAssessment.values.map((assessment) {
              return ActionChip(
                label: Text(
                  assessment.label(l10n),
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                onPressed: () => onSelected(assessment),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: onSkip,
            child: Text(
              l10n.common_skip,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
