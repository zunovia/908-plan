import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/highlight_card.dart';
import '../../providers/report_provider.dart';

class MonthlyReportScreen extends ConsumerStatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  ConsumerState<MonthlyReportScreen> createState() =>
      _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundManagerProvider).play(SoundId.ambientLoop, loop: true);
    });
  }

  @override
  void deactivate() {
    ref.read(soundManagerProvider).stop(SoundId.ambientLoop);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(monthlyReportProvider);

    return Scaffold(
      appBar: const ZeroAppBar(title: '月間レポート'),
      body: reportState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reportState.dateRange,
              style: AppTypography.body.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TrendLineChart(metrics: reportState.metrics),
            const SizedBox(height: AppSpacing.lg),
            HighlightCard(highlight: reportState.highlight),
            const SizedBox(height: AppSpacing.lg),
            if (reportState.inquiry != null)
              ZeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '先月との比較',
                      style: AppTypography.heading.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      reportState.inquiry!,
                      style: AppTypography.miniInsight.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            if (reportState.inquiry != null)
              const SizedBox(height: AppSpacing.lg),
            ZeroCard(
              child: Text(
                '月の中で声のトーンが変化するのは自然なことです。',
                style: AppTypography.body.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
