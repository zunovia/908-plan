import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../../data/report_model.dart';

class TrendLineChart extends StatelessWidget {
  final List<DailyMetric> metrics;

  const TrendLineChart({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.report_voice_trend,
            style: AppTypography.heading.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 150,
            child: metrics.isEmpty
                ? Center(
                    child: Text(
                      l10n.report_no_data,
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : CustomPaint(
                    size: const Size(double.infinity, 150),
                    painter: _TrendPainter(
                      metrics: metrics,
                      energyColor: Theme.of(context).colorScheme.primary,
                      clarityColor: Theme.of(context).colorScheme.secondary,
                      expressionColor: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(
                  context, l10n.report_energy, Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              _legendItem(
                  context, l10n.report_clarity, Theme.of(context).colorScheme.secondary),
              const SizedBox(width: AppSpacing.md),
              _legendItem(
                  context, l10n.report_expression, Theme.of(context).colorScheme.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<DailyMetric> metrics;
  final Color energyColor;
  final Color clarityColor;
  final Color expressionColor;

  _TrendPainter({
    required this.metrics,
    required this.energyColor,
    required this.clarityColor,
    required this.expressionColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.length < 2) {
      if (metrics.length == 1) {
        final cx = size.width / 2;
        canvas.drawCircle(Offset(cx, size.height * (1 - metrics[0].energy)),
            4, Paint()..color = energyColor);
        canvas.drawCircle(Offset(cx, size.height * (1 - metrics[0].clarity)),
            4, Paint()..color = clarityColor);
        canvas.drawCircle(
            Offset(cx, size.height * (1 - metrics[0].expressionRange)),
            4,
            Paint()..color = expressionColor);
      }
      return;
    }

    const padding = 8.0;
    final drawWidth = size.width - padding * 2;
    final step = drawWidth / (metrics.length - 1);

    void drawLine(List<double> values, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = padding + i * step;
        final y = size.height * (1 - values[i].clamp(0.0, 1.0));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      final dotPaint = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        final x = padding + i * step;
        final y = size.height * (1 - values[i].clamp(0.0, 1.0));
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    }

    drawLine(metrics.map((m) => m.energy).toList(), energyColor);
    drawLine(metrics.map((m) => m.clarity).toList(), clarityColor);
    drawLine(metrics.map((m) => m.expressionRange).toList(), expressionColor);
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.metrics != metrics;
}
