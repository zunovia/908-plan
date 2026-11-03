import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/release_repository.dart';
import '../../domain/records.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';
import '../widgets/record_card.dart';

/// 記録一覧（残した内容だけ・最後に手放した順）。チップで絞り込み、「もう一度手放す」、長押しで削除。広告なし。
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  String? _filter;

  Future<void> _confirmDelete(ReleaseSession record) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.rel_records_delete_title),
        content: Text(l10n.rel_records_delete_body),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l10n.rel_records_cancel)),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: Text(l10n.rel_records_delete)),
        ],
      ),
    );
    if (ok == true) await ref.read(releaseRepositoryProvider).deleteRecord(record.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final records = ref.watch(releaseRecordsProvider).valueOrNull ?? const <ReleaseSession>[];
    final tags = ReleaseRepository.recordFilterTags(records);
    final filter = (_filter != null && tags.contains(_filter)) ? _filter : null;
    final filtered = filter == null
        ? records
        : records.where((r) => r.memoryTags.contains(filter) || r.scene == filter).toList();

    return Scaffold(
      appBar: RelAppBar(title: l10n.rel_records_title),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          children: [
            if (tags.isNotEmpty)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  ChoiceChip(
                    label: Text(l10n.rel_records_filter_all),
                    selected: filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final t in tags)
                    ChoiceChip(
                      label: Text(relTagLabel(l10n, t)),
                      selected: filter == t,
                      onSelected: (_) => setState(() => _filter = filter == t ? null : t),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.rel_records_note, style: RelStyles.caption.copyWith(color: p.subText)),
            const SizedBox(height: AppSpacing.sm),
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(l10n.rel_records_empty, style: RelStyles.body.copyWith(color: p.subText)),
              ),
            for (final r in filtered) ...[
              RecordCard(
                key: ValueKey(r.id),
                record: r,
                onReleaseAgain: () => context.push(ReleasePaths.writeWith(source: r.id)),
                onLongPress: () => _confirmDelete(r),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
