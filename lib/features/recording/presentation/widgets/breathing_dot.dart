import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';

class BreathingDot extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const BreathingDot({super.key, required this.onComplete});

  @override
  ConsumerState<BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends ConsumerState<BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.breathingDot,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Play ambient breathing sound.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundManagerProvider).play(SoundId.breath, loop: true);
    });

    // Auto-advance after 3 seconds.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_completed) {
        _completed = true;
        widget.onComplete();
      }
    });
  }

  void _handleTapSkip() {
    if (_completed) return;
    _completed = true;
    _controller.stop();
    ref.read(soundManagerProvider).stop(SoundId.breath);
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTapSkip,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'タップでスキップ',
              style: AppTypography.caption.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
