import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import 'rel_styles.dart';

/// 端末内の決まった応答（反映・肯定・FAQ）の吹き出し。左寄せ。
class ReplyBubble extends StatelessWidget {
  const ReplyBubble({super.key, required this.text});

  /// 応答の本文。
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: p.surfaceSecondary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Text(text, style: RelStyles.body.copyWith(color: p.text, fontSize: 16, height: 1.7)),
        ),
      ),
    );
  }
}

/// 自分の発話（右寄せ）。
class UserBubble extends StatelessWidget {
  const UserBubble({super.key, required this.text});

  /// 書いた文・選んだ気持ち。
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 4),
          decoration: BoxDecoration(
            color: p.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Text(text, style: RelStyles.body.copyWith(color: p.text, fontSize: 16, height: 1.7)),
        ),
      ),
    );
  }
}

/// 再生リマインドの 1 行（左に小さな「✦」、氷の青の薄い帯）。
class ReplayLine extends StatelessWidget {
  const ReplayLine({super.key, required this.text});

  /// 「それは、ため込まれた記憶の再生かもしれません。」など。
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: p.ice.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text('✦', style: RelStyles.body.copyWith(color: p.ice))),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: RelStyles.body.copyWith(color: p.text, height: 1.5))),
        ],
      ),
    );
  }
}

/// カードの提示（「はじめる」と「別のカード」）。
class CardBubble extends StatelessWidget {
  const CardBubble({
    super.key,
    required this.text,
    this.prompt,
    required this.startLabel,
    required this.anotherLabel,
    required this.onStart,
    required this.onAnother,
  });

  /// カードの本文。
  final String text;

  /// 添えの一文。
  final String? prompt;
  final String startLabel;
  final String anotherLabel;
  final VoidCallback onStart;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.ice.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: RelStyles.body.copyWith(color: p.text, fontSize: 18, height: 1.5)),
          if (prompt != null && prompt!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(prompt!, style: RelStyles.caption.copyWith(color: p.subText, fontSize: 14)),
          ],
          const SizedBox(height: AppSpacing.sm + 4),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(onPressed: onStart, child: Text(startLabel)),
              TextButton(onPressed: onAnother, child: Text(anotherLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
