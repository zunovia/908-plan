import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';

class NormalizationCard extends StatelessWidget {
  const NormalizationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ZeroCard(
      child: Text(
        '週の中で声のトーンが変動するのは自然なことです。\n変化そのものが、あなたの声の個性です。',
        style: AppTypography.body.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
