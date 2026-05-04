import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../../../../shared/widgets/zero_card.dart';

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: ZeroAppBar(title: l10n.demo_title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.demo_experience_voxna,
              style: AppTypography.heading.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Sample report card
            ZeroCard(
              child: ListTile(
                title: Text(
                  l10n.demo_sample_report,
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  l10n.demo_weekly_report,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onTap: () => context.push('/demo/report'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Features card
            ZeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.demo_features,
                    style: AppTypography.heading.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _featureItem(context, l10n.demo_feature_daily),
                  _featureItem(context, l10n.demo_feature_ai),
                  _featureItem(context, l10n.demo_feature_reports),
                  _featureItem(context, l10n.demo_feature_patterns),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: ZeroButton(
                label: l10n.demo_start,
                onPressed: () => context.go('/home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            '• ',
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
