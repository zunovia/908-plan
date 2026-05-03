import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../../../../shared/widgets/zero_button.dart';
import '../../../../shared/widgets/zero_card.dart';

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ZeroAppBar(title: 'デモ'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voicellを体験する',
              style: AppTypography.heading.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Sample report card
            ZeroCard(
              child: ListTile(
                title: Text(
                  'サンプルレポートを見る',
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'ウィークリーレポート',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onTap: () => context.push('/demo/report'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Features card
            ZeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '機能一覧',
                    style: AppTypography.heading.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _featureItem(context, '毎日30秒の声の記録'),
                  _featureItem(context, 'AIによる問いかけ'),
                  _featureItem(context, '週次・月次レポート'),
                  _featureItem(context, '声のパターン追跡'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Center(
              child: ZeroButton(
                label: '始める →',
                onPressed: () => context.go('/home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Text(
            '• ',
            style: AppTypography.body.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
