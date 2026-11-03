import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import 'rel_styles.dart';

/// 相談窓口への導線バナー（危機判定の後 24 時間・柔らかい危機のとき）。
class CrisisBanner extends StatelessWidget {
  const CrisisBanner({super.key, required this.text, required this.actionLabel, required this.onTap});

  /// 一文（「いま、話を聞いてくれる人がいます。」）。
  final String text;

  /// 右の文字ボタン（「見る」）。
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Semantics(
      button: true,
      label: '$text $actionLabel',
      excludeSemantics: true,
      child: Material(
        color: p.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(child: Text(text, style: RelStyles.body.copyWith(color: p.text, fontSize: 14))),
                  const SizedBox(width: AppSpacing.sm),
                  Text(actionLabel, style: RelStyles.body.copyWith(color: p.accent, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
