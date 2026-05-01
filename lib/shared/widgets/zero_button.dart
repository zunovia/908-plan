import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/sound_manager.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';
import '../../core/providers/audio_providers.dart';

class ZeroButton extends ConsumerWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isOutlined;

  const ZeroButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void handlePress() {
      ref.read(soundManagerProvider).play(SoundId.click);
      onPressed();
    }

    if (isOutlined) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: handlePress,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: AppTypography.body.copyWith(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
