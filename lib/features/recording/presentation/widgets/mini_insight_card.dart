import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/insights/insight_engine.dart';
import '../../../../core/providers/storage_providers.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../../../release/presentation/release_ui.dart';
import '../../providers/recording_provider.dart';

class MiniInsightCard extends ConsumerWidget {
  final VoidCallback onNext;

  const MiniInsightCard({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recordingState = ref.watch(recordingProvider);

    // Get insight text from InsightEngine
    String insightText = l10n.insight_mini_tempo('3.0', l10n.insight_tempo_normal);
    final lastId = recordingState.lastRecordingId;
    if (lastId != null) {
      final repo = ref.read(localRecordingRepositoryProvider);
      final recordings = repo.getRecordings();
      final lastRecording =
          recordings.where((r) => r.id == lastId).firstOrNull;
      if (lastRecording != null) {
        insightText = InsightEngine.generateMiniInsight(lastRecording, l10n);
      }
    }

    // Split into main line and nuance line
    final lines = insightText.split('\n');
    final mainText = lines.length >= 2 ? '${lines[0]}\n${lines[1]}' : lines[0];
    final nuanceText = lines.length >= 3 ? lines[2] : l10n.insight_fallback_nuance;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: LayoutBuilder(
        // Scrolls on short screens; stays centred otherwise.
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.insight_voice_received,
                  style: AppTypography.philosophy.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  mainText,
                  style: AppTypography.miniInsight.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  nuanceText,
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ZeroButton(
                  label: l10n.common_next,
                  onPressed: onNext,
                ),
                if (lastId != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ReleaseThisVoiceButton(recordingId: lastId),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 「この声を手放す」: opens the release write screen with this recording's
/// voice tendency pre-selected as memory chips (the user can remove them).
class ReleaseThisVoiceButton extends ConsumerWidget {
  final String recordingId;

  const ReleaseThisVoiceButton({super.key, required this.recordingId});

  /// Route of the write screen for [recordingId].
  static String routeFor(String recordingId) =>
      Uri(path: '/release/write', queryParameters: {'voice': recordingId}).toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.onSurface;
    // The tendency needs a few earlier recordings to compare with; only
    // promise pre-selected chips when there are some.
    final hasTags = ref.watch(releaseVoiceTagsProvider(recordingId)).isNotEmpty;
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: () => context.push(routeFor(recordingId)),
          icon: const Icon(Icons.spa_outlined, size: 18),
          label: Text(l10n.rel_vx_release_this_voice),
        ),
        if (hasTags) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.rel_vx_release_this_voice_hint,
            style: AppTypography.caption.copyWith(
              color: color.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
