import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/records.dart';
import '../release_ui.dart';
import 'rel_styles.dart';

/// 記録 1 件のカード。本文（2 行まで、タップで全文）・日時・記憶チップ・場面・回数・「もう一度手放す」。
/// 長押しで削除（呼び出し側が確認ダイアログを出す）。
class RecordCard extends StatefulWidget {
  const RecordCard({super.key, required this.record, required this.onReleaseAgain, this.onLongPress});

  /// 表示する記録。
  final ReleaseSession record;
  final VoidCallback onReleaseAgain;

  /// 長押し（削除の確認）。
  final VoidCallback? onLongPress;

  @override
  State<RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<RecordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final r = widget.record;
    final tags = [...r.memoryTags, if (r.scene != null) r.scene!];
    return Material(
      color: p.surfaceSecondary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md - 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.note ?? l10n.rel_records_not_kept,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: RelStyles.body.copyWith(color: p.text, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: AppSpacing.xs + 2),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(relTimeLabel(r.sortAt, l10n.localeName), style: RelStyles.caption.copyWith(color: p.subText, fontSize: 11)),
                  for (final t in tags) RelTagPill(label: relTagLabel(l10n, t)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.rel_records_times(r.releaseCount),
                      style: RelStyles.caption.copyWith(color: p.subText, fontSize: 12),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: widget.onReleaseAgain,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 40)),
                    child: Text(l10n.rel_records_again, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 小さなタグの丸札。
class RelTagPill extends StatelessWidget {
  const RelTagPill({super.key, required this.label});

  /// 表示名。
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: p.ice.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label, style: RelStyles.caption.copyWith(color: p.ice, fontSize: 11)),
    );
  }
}
