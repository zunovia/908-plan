import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../painters/intro_painter.dart';
import '../painters/particle.dart';

/// Callback reporting the current intro phase (1-5).
typedef PhaseChangedCallback = void Function(int phase);

class IntroRiveAnimation extends StatefulWidget {
  final bool isFirstLaunch;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final PhaseChangedCallback? onPhaseChanged;

  const IntroRiveAnimation({
    super.key,
    required this.isFirstLaunch,
    required this.onComplete,
    required this.onSkip,
    this.onPhaseChanged,
  });

  @override
  State<IntroRiveAnimation> createState() => _IntroRiveAnimationState();
}

class _IntroRiveAnimationState extends State<IntroRiveAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Particle> _particles;
  int _currentPhase = 0;
  bool _showSkip = false;
  bool _skipping = false;

  // Phase boundaries (progress 0.0-1.0)
  static const _phase1End = 0.20; // 0-3s
  static const _phase2End = 0.40; // 3-6s
  static const _phase3End = 0.67; // 6-10s
  static const _phase4End = 0.87; // 10-13s
  // Phase 5: 0.87-1.0        // 13-15s

  @override
  void initState() {
    super.initState();
    _particles = Particle.generate(8);

    if (widget.isFirstLaunch) {
      _controller = AnimationController(
        vsync: this,
        duration: AppDurations.introFull,
      );
      _controller.addListener(_onTick);
      _controller.addStatusListener(_onStatus);
      _controller.forward();
    } else {
      // 2nd+ launch: logo only for splashShort duration
      _controller = AnimationController(
        vsync: this,
        duration: AppDurations.splashShort,
      );
      _currentPhase = 4;
      _controller.addStatusListener(_onStatus);
      _controller.forward();
    }
  }

  void _onTick() {
    if (!mounted) return;

    final progress = _controller.value;
    final newPhase = _phaseFromProgress(progress);

    if (newPhase != _currentPhase) {
      _currentPhase = newPhase;
      widget.onPhaseChanged?.call(_currentPhase);
    }

    // Show skip button after Phase 1 (3s = progress 0.20)
    if (!_showSkip && progress >= _phase1End) {
      setState(() => _showSkip = true);
    }
  }

  int _phaseFromProgress(double p) {
    if (p < _phase1End) return 1;
    if (p < _phase2End) return 2;
    if (p < _phase3End) return 3;
    if (p < _phase4End) return 4;
    return 5;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onComplete();
    }
  }

  void _handleSkip() {
    if (_skipping) return;
    setState(() => _skipping = true);

    widget.onPhaseChanged?.call(4);
    _currentPhase = 4;

    // Reset controller to play logo-only for 1.5s
    _controller.removeListener(_onTick);
    _controller.removeStatusListener(_onStatus);
    _controller.stop();
    _controller.reset();
    _controller.duration = AppDurations.splashShort;
    _controller.addStatusListener(_onStatus);
    _controller.forward();

    widget.onSkip();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFirstLaunch || _skipping) {
      return _buildLogoOnly();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final skipVisible = _showSkip && !_skipping && progress < _phase3End;

        return Container(
          color: const Color(0xFF0A0A0F),
          child: Stack(
            children: [
              // CustomPaint for phases 1-3
              if (progress < _phase3End + 0.05)
                Positioned.fill(
                  child: CustomPaint(
                    painter: IntroPainter(
                      progress: progress,
                      particles: _particles,
                    ),
                  ),
                ),

              // Logo (Phase 4-5): fade in then fade out
              if (progress >= _phase3End)
                Center(
                  child: Opacity(
                    opacity: ((progress - _phase3End) / 0.10).clamp(0.0, 1.0),
                    child: _logoContent(),
                  ),
                ),

              // Global fade-out in Phase 5
              if (progress >= _phase4End)
                Positioned.fill(
                  child: ColoredBox(
                    color: Color.fromRGBO(
                      10,
                      10,
                      15,
                      ((progress - _phase4End) / (1.0 - _phase4End))
                          .clamp(0.0, 1.0),
                    ),
                  ),
                ),

              // Skip button — always in tree, opacity-controlled for animation
              Positioned(
                bottom: 60,
                right: 24,
                child: IgnorePointer(
                  ignoring: !skipVisible,
                  child: AnimatedOpacity(
                    opacity: skipVisible ? 0.4 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: _handleSkip,
                      child: Text(
                        'スキップ →',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFFE8E6E0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoOnly() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final opacity = progress < 0.3
            ? (progress / 0.3).clamp(0.0, 1.0)
            : progress > 0.75
                ? ((1.0 - progress) / 0.25).clamp(0.0, 1.0)
                : 1.0;

        return Container(
          color: const Color(0xFF0A0A0F),
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: _logoContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _logoContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Zero',
          style: AppTypography.philosophy.copyWith(
            color: const Color(0xFFE8E6E0),
            fontSize: 32,
            letterSpacing: 8,
            fontWeight: FontWeight.w300,
            height: null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '声の、鏡。',
          style: AppTypography.caption.copyWith(
            color: const Color(0xFFE8E6E0).withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
