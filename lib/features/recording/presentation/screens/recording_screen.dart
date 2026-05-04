import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../home/providers/home_provider.dart';
import '../../providers/recording_phase_provider.dart';
import '../../providers/recording_provider.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/arc_progress.dart';
import '../widgets/breathing_dot.dart';
import '../widgets/mini_insight_card.dart';
import '../widgets/self_assessment_chips.dart';
import '../widgets/quiet_word_text.dart';

class RecordingScreen extends ConsumerWidget {
  final int durationSeconds;

  const RecordingScreen({super.key, this.durationSeconds = 30});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(recordingPhaseProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (phase == RecordingPhase.recording) {
          ref.read(recordingProvider.notifier).stopRecording();
        }
        ref.read(soundManagerProvider).stopAll();
        ref.read(recordingPhaseProvider.notifier).reset();
        context.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (phase) {
          RecordingPhase.recording => _RecordingView(
              durationSeconds: durationSeconds,
              onCancel: () {
                ref.read(recordingProvider.notifier).stopRecording();
                ref.read(soundManagerProvider).stopAll();
                ref.read(recordingPhaseProvider.notifier).reset();
                context.pop();
              },
              onFinished: () async {
                final sound = ref.read(soundManagerProvider);
                await sound.stopAll();
                sound.play(SoundId.bowlStrike);
                HapticFeedback.mediumImpact();
                ref.read(recordingPhaseProvider.notifier).nextPhase();
              },
            ),
          RecordingPhase.breathing => BreathingDot(
              onComplete: () {
                ref.read(soundManagerProvider).stopAll();
                ref.read(recordingPhaseProvider.notifier).nextPhase();
              },
            ),
          RecordingPhase.miniInsight => MiniInsightCard(
              onNext: () {
                ref.read(recordingPhaseProvider.notifier).nextPhase();
              },
            ),
          RecordingPhase.selfAssessment => SelfAssessmentChips(
              onSelected: (assessment) async {
                ref.read(soundManagerProvider).play(SoundId.drop);
                HapticFeedback.selectionClick();
                await ref
                    .read(recordingProvider.notifier)
                    .saveSelfAssessment(assessment.name);
                ref.read(recordingPhaseProvider.notifier).nextPhase();
              },
              onSkip: () {
                ref.read(recordingPhaseProvider.notifier).nextPhase();
              },
            ),
          RecordingPhase.quietWord => QuietWordText(
              onComplete: () {
                ref.read(soundManagerProvider).stopAll();
                ref.read(recordingPhaseProvider.notifier).reset();
                ref.read(homeProvider.notifier).refreshData();
                context.go('/home');
              },
            ),
          },
        ),
      ),
    );
  }
}

class _RecordingView extends ConsumerStatefulWidget {
  final int durationSeconds;
  final VoidCallback onCancel;
  final VoidCallback onFinished;

  const _RecordingView({
    required this.durationSeconds,
    required this.onCancel,
    required this.onFinished,
  });

  @override
  ConsumerState<_RecordingView> createState() => _RecordingViewState();
}

class _RecordingViewState extends ConsumerState<_RecordingView> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Defer recording start to after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started && mounted) {
        _started = true;
        final duration = Duration(seconds: widget.durationSeconds);
        ref.read(recordingProvider.notifier).startRecording(duration: duration);
        ref.read(soundManagerProvider).play(SoundId.breathe, loop: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recordingState = ref.watch(recordingProvider);
    final elapsed = recordingState.elapsed;
    final total = recordingState.totalDuration;

    // Auto-complete when recording stops (totalDuration reached).
    ref.listen<RecordingState>(recordingProvider, (prev, next) {
      if (prev?.isRecording == true && !next.isRecording && next.filePath != null) {
        widget.onFinished();
      }
    });

    final elapsedStr = _formatDuration(elapsed);
    final totalStr = _formatDuration(total);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.recording_cancel,
              onPressed: widget.onCancel,
            ),
          ),
          const Spacer(),
          const WaveformVisualizer(),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$elapsedStr / $totalStr',
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const ArcProgress(),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(recordingProvider.notifier).stopRecording();
              // onFinished is triggered by ref.listen above when isRecording becomes false
            },
            icon: const Icon(Icons.stop),
            label: Text(l10n.recording_done),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString();
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
