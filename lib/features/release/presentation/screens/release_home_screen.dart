import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/release_repository.dart';
import '../../domain/records.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/crisis_banner.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';
import '../widgets/record_card.dart';
import '../widgets/today_card.dart';
import '../widgets/week_dots.dart';

/// 「手放す」タブ。Luckarise の Home（今日の一枚・大きな「手放す」・今月の回数・7 日・あとで手放す・おかえり・危機バナー）
/// と Review（よく手放した記憶・最近の記録 3 件・すべての記録）の要素を 1 画面にまとめたもの。広告なし。
class ReleaseHomeScreen extends ConsumerWidget {
  const ReleaseHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final summary = ref.watch(releaseSummaryProvider).valueOrNull ?? ReleaseSummary.empty;
    final pending = ref.watch(releasePendingProvider).valueOrNull ?? const <PendingEvent>[];
    final today = ref.watch(releaseTodayCardProvider).valueOrNull;
    final crisisBanner = ref.watch(releaseCrisisBannerProvider);
    final frequent = ref.watch(releaseFrequentTagsProvider).valueOrNull ?? const [];
    final records = ref.watch(releaseRecordsProvider).valueOrNull ?? const <ReleaseSession>[];
    final now = DateTime.fromMillisecondsSinceEpoch(ref.watch(releaseClockProvider)());
    final dateLabel = DateFormat('M/d (E)', l10n.localeName).format(now);
    final caption = RelStyles.caption.copyWith(color: p.subText);
    final sectionTitle = RelStyles.caption.copyWith(color: p.subText, fontSize: 11, letterSpacing: 1);

    return Scaffold(
      appBar: RelAppBar(title: l10n.rel_vx_tab_label, showBack: false),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          children: [
            Row(
              children: [
                Expanded(child: Text(dateLabel, style: RelStyles.body.copyWith(color: p.text))),
                Text(l10n.rel_home_month_count(summary.monthCount), style: caption),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            WeekDots(days: summary.last7, semanticLabel: l10n.rel_home_last7_description),
            const SizedBox(height: AppSpacing.md),
            if (crisisBanner) ...[
              CrisisBanner(
                text: l10n.rel_home_crisis_banner_text,
                actionLabel: l10n.rel_home_crisis_banner_action,
                onTap: () => context.push(ReleasePaths.crisis),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (today != null && today.word.trim().isNotEmpty) ...[
              TodayCard(
                eyebrow: l10n.rel_home_today_card,
                word: today.word,
                line: today.line,
                tapHint: l10n.rel_home_today_tap,
                onTap: () => context.push(ReleasePaths.quick),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!summary.hasAny) ...[
              Text(l10n.rel_home_first_time_hint, style: RelStyles.body.copyWith(color: p.subText)),
              const SizedBox(height: AppSpacing.md),
            ],
            RelPrimaryButton(
              label: l10n.rel_home_letgo,
              height: 64,
              onPressed: () => context.push(ReleasePaths.write),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(ReleasePaths.chat),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text(l10n.rel_chat_title),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(ReleasePaths.breath),
                    icon: const Icon(Icons.air, size: 18),
                    label: Text(l10n.rel_breath_title),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addLater(ref),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(l10n.rel_review_later_title),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
            ),
            if (summary.welcomeBack)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(l10n.rel_home_welcome_back, textAlign: TextAlign.center, style: caption),
              ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _PendingCard(pending: pending),
            ],
            if (frequent.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.rel_review_often_title, style: sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 6,
                children: [
                  for (final f in frequent) RelTagPill(label: '${relTagLabel(l10n, f.tag)} ${f.count}'),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: Text(l10n.rel_records_title, style: sectionTitle)),
                TextButton(
                  onPressed: () => context.push(ReleasePaths.records),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.rel_review_records_all),
                ),
              ],
            ),
            if (records.isEmpty)
              Text(l10n.rel_records_empty, style: caption)
            else
              for (final r in records.take(3)) ...[
                RecordCard(
                  record: r,
                  onReleaseAgain: () => context.push(ReleasePaths.writeWith(source: r.id)),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  /// 「あとで手放す」: いまの時刻を待ち行列に入れる（後で書く画面から手放せる）。
  Future<void> _addLater(WidgetRef ref) async {
    final repo = ref.read(releaseRepositoryProvider);
    await repo.addPendingEvent(repo.nowMillis());
  }
}

class _PendingCard extends ConsumerWidget {
  const _PendingCard({required this.pending});

  final List<PendingEvent> pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.rel_home_pending_count(pending.length),
            style: RelStyles.caption.copyWith(color: p.subText, fontSize: 11, letterSpacing: 1),
          ),
          for (final e in pending.take(5))
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.rel_review_later_item(relTimeLabel(e.occurredAt, l10n.localeName)),
                    style: RelStyles.body.copyWith(color: p.text, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(releaseRepositoryProvider).deletePendingEvent(e.id),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.rel_review_later_dismiss),
                ),
                OutlinedButton(
                  onPressed: () => context.push(ReleasePaths.writeWith(pending: e.id)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
                  child: Text(l10n.rel_review_later_now),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
