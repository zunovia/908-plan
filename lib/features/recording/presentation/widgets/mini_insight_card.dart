import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/insights/insight_engine.dart';
import '../../../../core/providers/storage_providers.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../../providers/recording_provider.dart';

class MiniInsightCard extends ConsumerWidget {
  final VoidCallback onNext;

  const MiniInsightCard({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingProvider);

    // Get insight text from InsightEngine
    String insightText = '今日の声のテンポは、\n1秒あたり3.0音節でした。\n自然なペースの語りでした。';
    final lastId = recordingState.lastRecordingId;
    if (lastId != null) {
      final repo = ref.read(localRecordingRepositoryProvider);
      final recordings = repo.getRecordings();
      final lastRecording =
          recordings.where((r) => r.id == lastId).firstOrNull;
      if (lastRecording != null) {
        insightText = InsightEngine.generateMiniInsight(lastRecording);
      }
    }

    // Split into main line and nuance line
    final lines = insightText.split('\n');
    final mainText = lines.length >= 2 ? '${lines[0]}\n${lines[1]}' : lines[0];
    final nuanceText = lines.length >= 3 ? lines[2] : 'これがどう変化していくかは、時間が教えてくれます。';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'あなたの声を\n受け取りました。',
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
            label: '次へ',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
