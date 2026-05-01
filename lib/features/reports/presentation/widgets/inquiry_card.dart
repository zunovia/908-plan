import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';

class InquiryCard extends StatelessWidget {
  final String? inquiry;

  const InquiryCard({super.key, this.inquiry});

  @override
  Widget build(BuildContext context) {
    final text = inquiry ?? '今週の声に、耳を澄ませてみてください。';

    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '問いかけ',
            style: AppTypography.heading.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            text,
            style: AppTypography.philosophy.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
