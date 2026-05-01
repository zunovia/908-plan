import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../widgets/text_fade_in.dart';

class MetaphorScreen extends StatelessWidget {
  const MetaphorScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  '2/6',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const Spacer(),
              TextFadeIn(
                text: 'あなたの声は、\n静かな湖のようなものです。\n\n'
                    '場面によって風が吹き、\n波の形が変わる。\n'
                    'でも湖は一つです。\n\n'
                    'Zeroは、\nその湖面を映す場所です。\n\n'
                    '毎日30秒、\n声を聴かせてください。\n'
                    '波の下にある、\n静かな響きが見えてきます。',
                style: AppTypography.philosophy,
              ),
              const Spacer(),
              ZeroButton(
                label: '始める',
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
