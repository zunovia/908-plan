import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../onboarding/providers/onboarding_provider.dart';

class FirstRecordingScreen extends ConsumerWidget {
  const FirstRecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.topRight,
                child: Text(
                  '5/5',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                l10n.onboarding_first_question,
                style: AppTypography.philosophy.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Recording button — 80dp circle
              Semantics(
                button: true,
                label: l10n.onboarding_start_recording,
                child: GestureDetector(
                  onTap: () {
                    // Mark onboarding complete and navigate to recording
                    ref.read(onboardingCompleteProvider.notifier).complete();
                    context.go('/recording');
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Icon(
                      Icons.fiber_manual_record,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.onboarding_first_seconds,
                style: AppTypography.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
