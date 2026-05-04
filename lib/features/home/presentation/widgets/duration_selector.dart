import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

enum RecordingDuration {
  short15(15),
  normal30(30),
  long60(60);

  final int seconds;
  const RecordingDuration(this.seconds);

  String label(AppLocalizations l10n) => switch (this) {
    short15 => l10n.duration_short,
    normal30 => l10n.duration_normal,
    long60 => l10n.duration_long,
  };
}

class DurationSelector extends StatelessWidget {
  final RecordingDuration selected;
  final ValueChanged<RecordingDuration> onChanged;

  const DurationSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: RecordingDuration.values.map((duration) {
        final isSelected = duration == selected;
        return Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ChoiceChip(
            label: Text(
              duration.label(l10n),
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            selected: isSelected,
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            onSelected: (_) => onChanged(duration),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          ),
        );
      }).toList(),
    );
  }
}
