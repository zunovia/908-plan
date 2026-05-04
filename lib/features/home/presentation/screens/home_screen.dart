import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../widgets/daily_prompt_card.dart';
import '../widgets/duration_selector.dart';
import '../widgets/zero_score_section.dart';
import '../../providers/home_provider.dart';
import '../../data/daily_prompts.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      appBar: const ZeroAppBar(title: 'Voxna'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              // ZERO score + stage badge + convergence ring
              const ZeroScoreSection(),
              const SizedBox(height: AppSpacing.lg),
              // Streak count
              Text(
                homeState.streak > 0
                    ? l10n.home_streak(homeState.streak)
                    : l10n.home_start_today,
                style: AppTypography.body.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Daily prompt
              DailyPromptCard(prompt: getDailyPrompt(l10n, homeState.promptDayNumber)),
              const SizedBox(height: AppSpacing.lg),
              // Duration selector
              DurationSelector(
                selected: homeState.selectedDuration,
                onChanged: (duration) {
                  ref.read(homeProvider.notifier).setDuration(duration);
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              // Recording button
              Semantics(
                button: true,
                label: l10n.onboarding_start_recording,
                child: GestureDetector(
                  onTap: () => context.push(
                    '/recording?duration=${homeState.selectedDuration.seconds}',
                  ),
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
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
