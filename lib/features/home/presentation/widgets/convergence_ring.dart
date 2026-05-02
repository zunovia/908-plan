import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/insights/zero_score.dart';

/// Displays four concentric arcs (energy, clarity, expressionRange, tempo).
/// Each arc's radius shrinks as variability approaches zero.
/// When all arcs collapse to the center, the voice has reached ZERO.
class ConvergenceRing extends StatelessWidget {
  final ZeroRingData data;
  final double size;

  const ConvergenceRing({
    super.key,
    required this.data,
    this.size = 160,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ConvergenceRingPainter(
          data: data,
          isDark: isDark,
        ),
        child: Center(
          child: Text(
            'ZERO',
            style: AppTypography.caption.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConvergenceRingPainter extends CustomPainter {
  final ZeroRingData data;
  final bool isDark;

  const _ConvergenceRingPainter({
    required this.data,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 8;

    // Each ring gets a fraction of the total radius based on its variability.
    // variability 0.0 → radius ~0 (converged), 1.0 → full allocated radius.
    // Four rings, allocate equal "slots" from outside in.
    //   Ring 1 (outermost): energy
    //   Ring 2: clarity
    //   Ring 3: expressionRange
    //   Ring 4 (innermost): tempo
    const ringCount = 4;
    final slotWidth = maxRadius / ringCount;

    final metrics = [
      _RingSpec(
        value: data.energy,
        color: isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm,
        label: 'E',
      ),
      _RingSpec(
        value: data.clarity,
        color: isDark ? AppColors.darkAccentCool : AppColors.lightAccentCool,
        label: 'C',
      ),
      _RingSpec(
        value: data.expressionRange,
        color: isDark ? AppColors.darkAccentCalm : AppColors.lightAccentCalm,
        label: 'X',
      ),
      _RingSpec(
        value: data.tempo,
        color: isDark
            ? const Color(0xFF9A7EC4)
            : const Color(0xFF7A5EB8),
        label: 'T',
      ),
    ];

    for (int i = 0; i < metrics.length; i++) {
      final spec = metrics[i];
      // Base radius for this slot (outermost = maxRadius, innermost = slotWidth)
      final outerRadius = maxRadius - (i * slotWidth);
      // The arc radius scales with variability: fully variable → full slot,
      // fully converged → almost zero (but keep minRadius for visibility).
      final minRadius = 4.0;
      final arcRadius = minRadius + (outerRadius - slotWidth - minRadius) * spec.value;

      if (arcRadius <= 0) continue;

      // Draw background track
      final trackPaint = Paint()
        ..color = spec.color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, outerRadius - slotWidth / 2, trackPaint);

      // Draw active arc (270 degrees, starting from top)
      final arcPaint = Paint()
        ..color = spec.color.withValues(alpha: spec.value > 0.05 ? 0.85 : 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * 0.75; // 270 degrees
      const startAngle = -math.pi / 2 - (math.pi * 0.75 / 2); // centered at top

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }

    // Draw center dot — glows when approaching ZERO
    final avgVariability =
        (data.energy + data.clarity + data.expressionRange + data.tempo) / 4;
    final centerGlow = 1.0 - avgVariability;
    if (centerGlow > 0.5) {
      final glowPaint = Paint()
        ..color = (isDark ? AppColors.darkAccentWarm : AppColors.lightAccentWarm)
            .withValues(alpha: (centerGlow - 0.5) * 0.6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 8 * centerGlow, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ConvergenceRingPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.isDark != isDark;
  }
}

class _RingSpec {
  final double value;
  final Color color;
  final String label;

  const _RingSpec({
    required this.value,
    required this.color,
    required this.label,
  });
}
