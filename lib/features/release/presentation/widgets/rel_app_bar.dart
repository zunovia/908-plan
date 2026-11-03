import 'package:flutter/material.dart';

import '../release_ui.dart';
import 'rel_styles.dart';

/// 手放す画面の上部（戻る＋題）。Voxna の ZeroAppBar と同じ見た目で、google_fonts は RelStyles 経由。
class RelAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RelAppBar({super.key, this.title, this.onBack, this.actions, this.showBack = true});

  /// 題（無ければ空）。
  final String? title;

  /// 戻るを押したとき（既定は [relBack]）。
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final p = RelPalette.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => relBack(context),
            )
          : null,
      title: title == null ? null : Text(title!, style: RelStyles.heading.copyWith(color: p.text, fontSize: 18)),
      actions: actions,
    );
  }
}

/// 全幅の主ボタン（高さ [height]）。
class RelPrimaryButton extends StatelessWidget {
  const RelPrimaryButton({super.key, required this.label, required this.onPressed, this.height = 52});

  /// ボタンの文言。
  final String label;

  /// null なら押せない。
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: RelStyles.body.copyWith(color: scheme.onPrimary, fontSize: height >= 60 ? 19 : 15)),
      ),
    );
  }
}
