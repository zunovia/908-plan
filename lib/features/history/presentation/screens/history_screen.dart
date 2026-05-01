import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_app_bar.dart';
import '../widgets/calendar_grid.dart';
import '../widgets/day_detail_card.dart';
import '../../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: const ZeroAppBar(title: '履歴'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CalendarGrid(
              recordedDates: historyState.recordedDates,
              selectedDate: historyState.selectedDate,
              onDateSelected: (date) {
                ref.read(historyProvider.notifier).selectDate(date);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '● = 録音あり  ○ = なし',
              style: AppTypography.caption.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (historyState.selectedDate != null)
              DayDetailCard(
                date: historyState.selectedDate!,
                recordings: historyState.selectedDateRecordings,
              )
            else if (historyState.recordedDates.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: Center(
                  child: Text(
                    'まだ録音がありません。\n最初の声を記録してみましょう。',
                    style: AppTypography.body.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
