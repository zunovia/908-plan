import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_colors.dart';

enum SelfAssessment {
  calm('穏やか'),
  normal('普通'),
  shaky('揺れている'),
  unknown('わからない');

  final String label;
  const SelfAssessment(this.label);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '今の声、\nどう感じましたか？',
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
                  assessment.label,
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
              'スキップ',
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
