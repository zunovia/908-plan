import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';

class InquiryCard extends StatelessWidget {
  final String? inquiry;

  const InquiryCard({super.key, this.inquiry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = inquiry ?? l10n.report_inquiry_fallback;

    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.report_inquiry,
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
