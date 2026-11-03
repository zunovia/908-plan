import 'package:flutter/material.dart';

import 'rel_styles.dart';

/// 最近 7 日の点灯（古い順、右端が今日）。数は出さず、休んだ日は薄い輪のまま（責めない）。
class WeekDots extends StatelessWidget {
  const WeekDots({super.key, required this.days, required this.semanticLabel});

  /// 7 日分の実践の有無（古い順）。
  final List<bool> days;

  /// 読み上げ用の説明（例「最近7日」）。
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    final on = days.where((d) => d).length;
    return Semantics(
      label: '$semanticLabel $on/${days.length}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: d ? p.accent : Colors.transparent,
                  border: Border.all(color: d ? p.accent : p.muted, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
