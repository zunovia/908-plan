import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';

class HighlightCard extends StatelessWidget {
  final String? highlight;

  const HighlightCard({super.key, this.highlight});

  @override
  Widget build(BuildContext context) {
    final text = highlight ?? 'まだ十分なデータがありません';

    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ハイライト',
            style: AppTypography.heading.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
