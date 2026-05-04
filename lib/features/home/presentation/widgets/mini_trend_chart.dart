import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../../../recording/data/recording_model.dart';
import '../../providers/home_provider.dart';

class MiniTrendChart extends ConsumerWidget {
  const MiniTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final homeState = ref.watch(homeProvider);
    final spots = _buildSpots(homeState.recentRecordings);
    final accent = Theme.of(context).colorScheme.primary;

    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.home_weekly_voice,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 60,
            child: spots.length < 2
                ? Center(
                    child: Text(
                      l10n.home_collecting_data,
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: 1,
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: accent,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 3,
                              color: accent,
                              strokeWidth: 0,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: accent.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      lineTouchData: const LineTouchData(enabled: false),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.home_days_recording(homeState.dayCount),
            style: AppTypography.caption.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _buildSpots(List<RecordingModel> recordings) {
    if (recordings.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Group by day offset (0 = 6 days ago, 6 = today)
    final dayAverages = <int, List<double>>{};
    for (final r in recordings) {
      final rDay = DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day);
      final offset = today.difference(rDay).inDays;
      if (offset < 0 || offset > 6) continue;
      final x = 6 - offset; // 0=oldest, 6=today
      final energy = r.energy;
      if (energy != null) {
        dayAverages.putIfAbsent(x, () => []).add(energy);
      }
    }

    return dayAverages.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return FlSpot(e.key.toDouble(), avg.clamp(0.0, 1.0));
    }).toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }
}
