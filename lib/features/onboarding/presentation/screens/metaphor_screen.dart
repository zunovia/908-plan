import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../widgets/text_fade_in.dart';

class MetaphorScreen extends StatelessWidget {
  const MetaphorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              const SizedBox(height: AppSpacing.md),
              const Spacer(),
              TextFadeIn(
                text: l10n.onboarding_metaphor_text,
                style: AppTypography.philosophy,
              ),
              const Spacer(),
              ZeroButton(
                label: l10n.common_start,
                onPressed: () => context.go('/onboarding/mechanism'),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
