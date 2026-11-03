import 'package:flutter/material.dart';

import 'rel_styles.dart';

/// 5 つの濃淡の円（表情なし）で気分を選ぶ。選ばなくてよい。
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.selected, required this.onSelect, required this.semanticLabelFor});

  /// 選んだ段階（1〜5）。null なら未選択。
  final int? selected;
  final ValueChanged<int> onSelect;

  /// 読み上げ用（例「気分 3/5」）。
  final String Function(int level) semanticLabelFor;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var level = 1; level <= 5; level++)
          Semantics(
            button: true,
            selected: selected == level,
            label: semanticLabelFor(level),
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => onSelect(level),
              radius: 24,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: selected == level ? 34 : 26,
                    height: selected == level ? 34 : 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.ice.withValues(alpha: 0.2 + (level - 1) * 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
