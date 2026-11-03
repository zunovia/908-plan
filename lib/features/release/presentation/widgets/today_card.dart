import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import 'rel_styles.dart';

/// 「今日の一枚」: 語（大）＋一文＋タップの案内。タップで 15 秒のひと言へ。
class TodayCard extends StatelessWidget {
  const TodayCard({
    super.key,
    required this.eyebrow,
    required this.word,
    this.line,
    required this.tapHint,
    required this.onTap,
  });

  /// 上の小さな見出し（「今日の一枚」）。
  final String eyebrow;

  /// 今日の語。
  final String word;

  /// 今日の一文。
  final String? line;

  /// タップの案内。
  final String tapHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Semantics(
      button: true,
      label: '$eyebrow $word. $tapHint',
      excludeSemantics: true,
      child: Material(
        color: p.ice.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  style: RelStyles.caption.copyWith(color: p.subText, fontSize: 11, letterSpacing: 1),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  word,
                  textAlign: TextAlign.center,
                  style: RelStyles.heading.copyWith(color: p.text, fontSize: 34, height: 1.3, fontWeight: FontWeight.w400),
                ),
                if (line != null && line!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(line!, textAlign: TextAlign.center, style: RelStyles.line.copyWith(color: p.text, fontSize: 14)),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(tapHint, textAlign: TextAlign.center, style: RelStyles.caption.copyWith(color: p.subText, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
