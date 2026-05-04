import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../../../reports/data/report_model.dart';
import '../../../reports/presentation/widgets/trend_line_chart.dart';
import '../../../reports/presentation/widgets/highlight_card.dart';
import '../../../reports/presentation/widgets/inquiry_card.dart';
import '../../../reports/presentation/widgets/normalization_card.dart';

class DemoReportScreen extends StatelessWidget {
  const DemoReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final metrics = List.generate(5, (i) {
      final day = weekStart.add(Duration(days: i));
      return DailyMetric(
        date: day,
        energy: [0.65, 0.72, 0.55, 0.80, 0.68][i],
        clarity: [0.70, 0.68, 0.75, 0.82, 0.71][i],
        expressionRange: [0.45, 0.52, 0.38, 0.60, 0.50][i],
      );
    });

    return Scaffold(
      appBar: ZeroAppBar(title: l10n.demo_sample_title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                l10n.demo_sample_data,
                style: AppTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.demo_weekly_report,
              style: AppTypography.body.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TrendLineChart(metrics: metrics),
            const SizedBox(height: AppSpacing.lg),
            HighlightCard(
              highlight: l10n.demo_highlight,
            ),
            const SizedBox(height: AppSpacing.lg),
            const InquiryCard(),
            const SizedBox(height: AppSpacing.lg),
            const NormalizationCard(),
          ],
        ),
      ),
    );
  }
}
