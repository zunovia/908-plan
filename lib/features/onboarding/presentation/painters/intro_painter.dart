import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'particle.dart';

/// Intro animation phases mapped to progress [0.0 - 1.0].
///
/// Phase 1 (0.00 - 0.20): Light particle — glow pulse at center
/// Phase 2 (0.20 - 0.40): Breathing — scale oscillation + floating particles
/// Phase 3 (0.40 - 0.67): Ripples — concentric circles expanding outward
/// Phase 4-5 (0.67 - 1.00): Logo display handled by widget layer (no painting)
class IntroPainter extends CustomPainter {
  final double progress;
  final List<Particle> particles;

  static const _bgColor = Color(0xFF0A0A0F);
  static const _glowColor = Color(0xFFE8E6E0);

  IntroPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _bgColor,
    );

    if (progress < 0.20) {
      _drawPhase1(canvas, size, center);
    } else if (progress < 0.40) {
      _drawPhase2(canvas, size, center);
    } else if (progress < 0.67) {
      _drawPhase3(canvas, size, center);
    }
    // Phase 4-5: no custom painting (logo handled by widget)
  }

  /// Phase 1: Single glowing particle with gentle pulsing
  void _drawPhase1(Canvas canvas, Size size, Offset center) {
    // Fade in over the first 20% of phase 1
    final phaseLocal = progress / 0.20;
    final fadeIn = (phaseLocal * 5.0).clamp(0.0, 1.0);

    // Sine-wave pulse for opacity
    final pulse = 0.5 + 0.5 * sin(progress * 2 * pi * 5);
    final opacity = fadeIn * (0.6 + 0.4 * pulse);

    _drawGlow(canvas, center, 6.0, opacity);
  }

  /// Phase 2: Center particle breathes (scale oscillation) + orbiting particles
  void _drawPhase2(Canvas canvas, Size size, Offset center) {
    final phaseLocal = (progress - 0.20) / 0.20;

    // Breathing scale: oscillates between 0.6x and 1.4x
    final breathScale = 1.0 + 0.4 * sin(phaseLocal * 2 * pi * 2);
    final coreRadius = 6.0 * breathScale;

    _drawGlow(canvas, center, coreRadius, 0.9);

    // Floating particles fade in
    final particleFadeIn = (phaseLocal * 3.0).clamp(0.0, 1.0);

    for (final p in particles) {
      final angle = p.angle + phaseLocal * p.speed * 2 * pi;
      final radius = p.baseRadius * (0.8 + 0.2 * sin(phaseLocal * pi * 2 + p.phaseOffset));
      final px = center.dx + cos(angle) * radius;
      final py = center.dy + sin(angle) * radius;
      final particleOpacity = particleFadeIn * (0.3 + 0.3 * sin(phaseLocal * pi * 4 + p.phaseOffset));

      canvas.drawCircle(
        Offset(px, py),
        p.size,
        Paint()
          ..color = _glowColor.withValues(alpha: particleOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );
    }
  }

  /// Phase 3: Concentric ripples expanding from center + particles riding ripples
  void _drawPhase3(Canvas canvas, Size size, Offset center) {
    final phaseLocal = (progress - 0.40) / 0.27;
    final maxRippleRadius = size.width * 0.45;

    // Draw up to 4 ripples
    for (int i = 0; i < 4; i++) {
      final rippleDelay = i * 0.2;
      final rippleProgress = ((phaseLocal - rippleDelay) / 0.6).clamp(0.0, 1.0);

      if (rippleProgress <= 0) continue;

      final radius = rippleProgress * maxRippleRadius;
      final opacity = (1.0 - rippleProgress) * 0.5;

      if (opacity <= 0) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = _glowColor.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * (1.0 - rippleProgress * 0.5),
      );
    }

    // Core glow shrinks as ripples expand
    final coreOpacity = (1.0 - phaseLocal).clamp(0.0, 1.0) * 0.8;
    _drawGlow(canvas, center, 4.0, coreOpacity);

    // Particles flow outward along ripples
    for (final p in particles) {
      final angle = p.angle + phaseLocal * p.speed * pi;
      final radius = p.baseRadius * (1.0 + phaseLocal * 2.0);
      final px = center.dx + cos(angle) * radius;
      final py = center.dy + sin(angle) * radius;
      final particleOpacity = (1.0 - phaseLocal) * 0.4;

      if (particleOpacity <= 0) continue;

      canvas.drawCircle(
        Offset(px, py),
        p.size * 0.8,
        Paint()
          ..color = _glowColor.withValues(alpha: particleOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  /// Draw a radial-gradient glow circle
  void _drawGlow(Canvas canvas, Offset center, double radius, double opacity) {
    if (opacity <= 0) return;

    final glowRadius = radius * 4;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        glowRadius,
        [
          _glowColor.withValues(alpha: opacity),
          _glowColor.withValues(alpha: opacity * 0.3),
          _glowColor.withValues(alpha: 0),
        ],
        [0.0, 0.4, 1.0],
      );

    canvas.drawCircle(center, glowRadius, paint);

    // Bright core
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _glowColor.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
  }

  @override
  bool shouldRepaint(IntroPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
