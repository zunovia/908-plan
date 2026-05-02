import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/insights/zero_score.dart';
import '../../../../features/reports/data/report_model.dart';
import '../../../../features/recording/data/recording_model.dart';
import '../../providers/home_provider.dart';
import 'convergence_ring.dart';

/// Displays the ZERO score, stage badge, and convergence ring on the home screen.
class ZeroScoreSection extends ConsumerWidget {
  const ZeroScoreSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dailyMetrics = _buildDailyMetrics(homeState.recentRecordings);
    final zeroScore = ZeroScore.compute(dailyMetrics);
    final ringData = ZeroScore.computeRingData(dailyMetrics);

    return Column(
      children: [
        // Score + badge row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Score number
            Text(
              zeroScore != null ? '${zeroScore.score}' : '--',
              style: AppTypography.data.copyWith(
                fontSize: 56,
                fontWeight: FontWeight.w200,
                height: 1.1,
                color: zeroScore != null
                    ? _scoreColor(zeroScore.score, isDark)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Stage badge + label
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (zeroScore != null)
                    _StageBadge(
                      stage: zeroScore.stage,
                      label: zeroScore.stageLabel,
                      isDark: isDark,
                    )
                  else
                    _InsufficientDataBadge(isDark: isDark),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    zeroScore != null ? '声の安定スコア' : '7日分記録後に表示',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Convergence ring
        ringData != null
            ? ConvergenceRing(data: ringData)
            : _RingPlaceholder(isDark: isDark),
        const SizedBox(height: AppSpacing.xs),
        // Legend row
        _RingLegend(isDark: isDark),
      ],
    );
  }

  /// Converts recent RecordingModel list to per-day DailyMetric list.
  /// If multiple recordings exist on the same day, averages are used.
  List<DailyMetric> _buildDailyMetrics(List<RecordingModel> recordings) {
    final byDay = <String, List<RecordingModel>>{};
    for (final r in recordings) {
      if (r.energy == null) continue;
      final key =
          '${r.recordedAt.year}-${r.recordedAt.month.toString().padLeft(2, '0')}-${r.recordedAt.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(r);
    }

    return byDay.entries.map((e) {
      final recs = e.value;
      final avg = (List<double> vals) => vals.reduce((a, b) => a + b) / vals.length;
      return DailyMetric(
        date: DateTime.parse(e.key),
        energy: avg(recs.map((r) => r.energy!).toList()),
        clarity: avg(recs.map((r) => r.clarity ?? 0.5).toList()),
        expressionRange: avg(recs.map((r) => r.expressionRange ?? 0.5).toList()),
        tempo: avg(recs.map((r) => r.tempo ?? 3.0).toList()),
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Color _scoreColor(int score, bool isDark) {
    // ZERO range (< 5): accent warm glow
    // Low (< 20): calm green
    // Mid (< 60): cool blue
    // High (>= 60): muted warm
    if (score < 5) {
      return isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm;
    }
    if (score < 20) {
      return isDark ? AppColors.darkAccentCalm : AppColors.lightAccentCalm;
    }
    if (score < 60) {
      return isDark ? AppColors.darkAccentCool : AppColors.lightAccentCool;
    }
    return isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  }
}

class _StageBadge extends StatelessWidget {
  final int stage;
  final String label;
  final bool isDark;

  const _StageBadge({
    required this.stage,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isZero = stage == 0;
    final bg = isZero
        ? (isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm)
            .withValues(alpha: 0.18)
        : Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.8);
    final fg = isZero
        ? (isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: isZero
            ? Border.all(
                color: (isDark
                        ? AppColors.darkAccentWarm
                        : AppColors.lightAccentWarm)
                    .withValues(alpha: 0.5),
                width: 0.8,
              )
            : null,
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: fg,
          fontWeight: isZero ? FontWeight.w600 : FontWeight.w400,
          fontSize: 12,
          letterSpacing: isZero ? 1.5 : 0.3,
        ),
      ),
    );
  }
}

class _InsufficientDataBadge extends StatelessWidget {
  final bool isDark;

  const _InsufficientDataBadge({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        'データ不足',
        style: AppTypography.caption.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.35),
          fontSize: 11,
        ),
      ),
    );
  }
}

/// Placeholder ring shown when fewer than 7 days of data are available.
class _RingPlaceholder extends StatelessWidget {
  final bool isDark;

  const _RingPlaceholder({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _PlaceholderPainter(isDark: isDark),
        child: Center(
          child: Text(
            'ZERO',
            style: AppTypography.caption.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.15),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPainter extends CustomPainter {
  final bool isDark;

  const _PlaceholderPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 8;
    const ringCount = 4;
    final slotWidth = maxRadius / ringCount;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final baseColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    for (int i = 0; i < ringCount; i++) {
      final radius = maxRadius - (i * slotWidth) - slotWidth / 2;
      paint.color = baseColor.withValues(alpha: 0.12 + i * 0.03);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PlaceholderPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class _RingLegend extends StatelessWidget {
  final bool isDark;

  const _RingLegend({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final items = [
      _LegendItem(
        label: 'E',
        name: 'エネルギー',
        color: isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm,
      ),
      _LegendItem(
        label: 'C',
        name: '明瞭度',
        color: isDark ? AppColors.darkAccentCool : AppColors.lightAccentCool,
      ),
      _LegendItem(
        label: 'X',
        name: '抑揚',
        color: isDark ? AppColors.darkAccentCalm : AppColors.lightAccentCalm,
      ),
      _LegendItem(
        label: 'T',
        name: 'テンポ',
        color: isDark
            ? const Color(0xFF9A7EC4)
            : const Color(0xFF7A5EB8),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map(
            (item) => Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    item.name,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LegendItem {
  final String label;
  final String name;
  final Color color;

  const _LegendItem({
    required this.label,
    required this.name,
    required this.color,
  });
}
