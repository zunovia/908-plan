import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';

class QuietWordText extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const QuietWordText({super.key, required this.onComplete});

  @override
  ConsumerState<QuietWordText> createState() => _QuietWordTextState();
}

class _QuietWordTextState extends ConsumerState<QuietWordText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: AppDurations.quietWordIn.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 10000,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: AppDurations.quietWordOut.inMilliseconds.toDouble(),
      ),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_completed) {
        _completed = true;
        widget.onComplete();
      }
    });

    // Play singing bowl sustain sound.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(soundManagerProvider).play(SoundId.bowlSustain);
    });
  }

  void _handleTapSkip() {
    if (_completed) return;
    _completed = true;
    _controller.stop();
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTapSkip,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  l10n.quiet_word_text,
                  style: AppTypography.philosophy.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.common_tap_to_skip,
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
