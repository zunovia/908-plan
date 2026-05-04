import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

  String _localizeAssessment(String value, AppLocalizations l10n) {
    return switch (value) {
      'calm' => l10n.assessment_calm,
      'normal' => l10n.assessment_normal,
      'shaky' => l10n.assessment_shaky,
      'unknown' => l10n.assessment_unknown,
      _ => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('M/d (E)', Localizations.localeOf(context).languageCode);

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
              l10n.detail_no_recording,
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
          _detailRow(context, l10n.detail_duration, l10n.detail_duration_seconds(r.durationSeconds)),
          if (r.selfAssessment != null)
            _detailRow(context, l10n.detail_self_assessment, _localizeAssessment(r.selfAssessment!, l10n)),
          if (r.tempo != null)
            _detailRow(context, l10n.detail_tempo, l10n.detail_tempo_value(r.tempo!.toStringAsFixed(1))),
          if (r.energy != null)
            _detailRow(context, l10n.detail_energy, r.energy!.toStringAsFixed(2)),
          if (r.clarity != null)
            _detailRow(context, l10n.detail_clarity, r.clarity!.toStringAsFixed(2)),
          if (r.expressionRange != null)
            _detailRow(context, l10n.detail_expression_range, r.expressionRange!.toStringAsFixed(2)),
          if (recordings.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.detail_other_recordings(recordings.length - 1),
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
