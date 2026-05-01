import 'package:flutter/material.dart';

import '../../core/constants/app_typography.dart';

class ZeroAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const ZeroAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: AppTypography.heading.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
        ),
      ),
      actions: actions,
    );
  }
}
