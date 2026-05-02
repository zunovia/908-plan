import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

class DailyPromptCard extends StatelessWidget {
  final String prompt;

  const DailyPromptCard({super.key, required this.prompt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '今日の問いかけ:',
          style: AppTypography.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '「$prompt」',
          style: AppTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            height: 1.7,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
