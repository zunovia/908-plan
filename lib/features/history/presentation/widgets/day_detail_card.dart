import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../../../recording/data/recording_model.dart';

class DayDetailCard extends StatelessWidget {
  final DateTime date;
  final List<RecordingModel> recordings;

  const DayDetailCard({
    super.key,
    required this.date,
    required this.recordings,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('M/d (E)', 'ja');

    if (recordings.isEmpty) {
      return ZeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateFormat.format(date),
              style: AppTypography.heading.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'この日の録音はありません',
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final r = recordings.first;
    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateFormat.format(date),
            style: AppTypography.heading.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _detailRow(context, '録音時間', '${r.durationSeconds}秒'),
          if (r.selfAssessment != null)
            _detailRow(context, '自己評価', r.selfAssessment!),
          if (r.tempo != null)
            _detailRow(context, 'テンポ', '${r.tempo!.toStringAsFixed(1)}音節/秒'),
          if (r.energy != null)
            _detailRow(context, 'エネルギー', r.energy!.toStringAsFixed(2)),
          if (r.clarity != null)
            _detailRow(context, '明瞭度', r.clarity!.toStringAsFixed(2)),
          if (r.expressionRange != null)
            _detailRow(context, '表現幅', r.expressionRange!.toStringAsFixed(2)),
          if (recordings.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                '他 ${recordings.length - 1} 件の録音',
                style: AppTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
