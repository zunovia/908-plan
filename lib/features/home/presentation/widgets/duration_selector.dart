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

/// The 15 / 30 / 60 second choice on the home screen.
///
/// Chips keep their natural width (the selected one is shown by its filled
/// colour, without a checkmark, so selecting never changes its width) and sit
/// in a centred [Wrap]: one row when they fit, a second row instead of a cut
/// label when they do not (large font scale). A label that is wider than the
/// whole row on its own shrinks to fit rather than being clipped.
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
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: RecordingDuration.values.map((duration) {
        final isSelected = duration == selected;
        return ChoiceChip(
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              duration.label(l10n),
              maxLines: 1,
              softWrap: false,
              style: AppTypography.caption.copyWith(
                color: isSelected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
          selectedColor: scheme.primary,
          backgroundColor: scheme.surfaceContainerHighest,
          onSelected: (_) => onChanged(duration),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        );
      }).toList(),
    );
  }
}
