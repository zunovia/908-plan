import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../widgets/trend_line_chart.dart';
import '../widgets/highlight_card.dart';
import '../widgets/inquiry_card.dart';
import '../widgets/normalization_card.dart';
import '../../providers/report_provider.dart';

class WeeklyReportScreen extends ConsumerStatefulWidget {
  final String? reportId;

  const WeeklyReportScreen({super.key, this.reportId});

  @override
  ConsumerState<WeeklyReportScreen> createState() =>
      _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
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
    final reportState = ref.watch(reportProvider);

    return Scaffold(
      appBar: const ZeroAppBar(title: '週間レポート'),
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
                  InquiryCard(inquiry: reportState.inquiry),
                  const SizedBox(height: AppSpacing.lg),
                  const NormalizationCard(),
                ],
              ),
            ),
    );
  }
}
