import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../../../release/domain/weekly_letter.dart';
import '../../../release/providers/release_providers.dart';

/// Display label of a memory chip. Voice tendency tags ("voice:*") are shown
/// with their localized text; the user's own chips are shown as written.
String releaseTagLabel(AppLocalizations l10n, String tag) => switch (tag) {
      'voice:low_energy' => l10n.rel_vx_voice_low_energy,
      'voice:high_energy' => l10n.rel_vx_voice_high_energy,
      'voice:fast_tempo' => l10n.rel_vx_voice_fast_tempo,
      'voice:slow_tempo' => l10n.rel_vx_voice_slow_tempo,
      'voice:narrow_range' => l10n.rel_vx_voice_narrow_range,
      'voice:low_clarity' => l10n.rel_vx_voice_low_clarity,
      'voice:steady' => l10n.rel_vx_voice_steady,
      _ => tag,
    };

/// 今週の手紙の本文（Luckarise の WeeklyLetterCard と同じ組み立て）。
/// Facts only (counts, most frequent chip, days off) — no evaluation.
/// [localeName] is used for the short weekday names of rest days.
String composeReleaseLetter(AppLocalizations l10n, WeeklyStats? stats, String localeName) {
  if (stats == null || stats.thisWeekCount == 0) return l10n.rel_review_letter_empty;
  final b = StringBuffer(l10n.rel_review_letter_body(stats.thisWeekCount));
  final top = stats.topTag;
  if (top != null) {
    b.write(l10n.rel_review_letter_top(releaseTagLabel(l10n, top), stats.topTagCount));
  }
  final diff = stats.thisWeekCount - stats.lastWeekCount;
  if (stats.lastWeekCount != 0) {
    if (diff > 0) {
      b.write(l10n.rel_review_letter_more(diff));
    } else if (diff < 0) {
      b.write(l10n.rel_review_letter_fewer(-diff));
    } else {
      b.write(l10n.rel_review_letter_same);
    }
  }
  if (stats.restDays.isNotEmpty) {
    final format = DateFormat.E(localeName);
    // 2024-01-01 is a Monday: Monday + (weekday - 1) days.
    final names = stats.restDays
        .map((w) => format.format(DateTime(2024, 1, w)))
        .join(l10n.rel_review_letter_list_separator);
    b.write(l10n.rel_review_letter_rest(names));
  }
  return b.toString();
}

/// Weekly report card: this week's letter and release count. Tap → 手放す tab.
class ReleaseLetterCard extends ConsumerWidget {
  const ReleaseLetterCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(releaseWeeklyStatsProvider);
    // Storage unavailable → leave the report as it was.
    if (async.hasError) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final stats = async.valueOrNull;
    final localeName = Localizations.localeOf(context).languageCode;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final count = stats?.thisWeekCount ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => context.go('/release'),
        child: ZeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.rel_vx_weekly_letter_title,
                      style: AppTypography.heading.copyWith(color: onSurface, fontSize: 16),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: onSurface.withValues(alpha: 0.4)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                composeReleaseLetter(l10n, stats, localeName),
                style: AppTypography.body.copyWith(color: onSurface, height: 1.6),
              ),
              if (count > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.rel_vx_week_release_count_label,
                        style: AppTypography.body.copyWith(color: onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                    Text(
                      l10n.rel_vx_count_times(count),
                      style: AppTypography.body.copyWith(color: onSurface),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
