import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';

class ZeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ZeroCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: child,
    );
  }
}
