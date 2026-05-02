import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

enum RecordingDuration {
  short15('ひと息15秒', 15),
  normal30('いつもの30秒', 30),
  long60('じっくり60秒', 60);

  final String label;
  final int seconds;
  const RecordingDuration(this.label, this.seconds);
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: RecordingDuration.values.map((duration) {
        final isSelected = duration == selected;
        return Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ChoiceChip(
            label: Text(
              duration.label,
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
