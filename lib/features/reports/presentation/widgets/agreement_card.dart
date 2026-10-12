import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/insights/agreement_engine.dart';
import '../../../../shared/widgets/zero_card.dart';

/// Shows how often the user's own sense of their voice (the breath tap after
/// recording) overlapped with the data over the last two weeks.
class AgreementCard extends StatelessWidget {
  final AgreementResult result;

  const AgreementCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final String body;
    if (!result.hasEnoughData) {
      body = l10n.report_agreement_insufficient;
    } else {
      body = l10n.report_agreement_body(result.matched, result.total);
    }

    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.report_agreement_title,
            style: AppTypography.heading.copyWith(
              color: onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            body,
            style: AppTypography.body.copyWith(color: onSurface),
          ),
          if (result.isRising) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.report_agreement_rising,
              style: AppTypography.philosophy.copyWith(
                color: onSurface.withValues(alpha: 0.85),
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
