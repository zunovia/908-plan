import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';

class CalendarGrid extends StatefulWidget {
  final Set<DateTime> recordedDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const CalendarGrid({
    super.key,
    required this.recordedDates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<CalendarGrid> createState() => _CalendarGridState();
}

class _CalendarGridState extends State<CalendarGrid> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
    );
    // Don't navigate beyond current month
    if (nextMonth.year > now.year ||
        (nextMonth.year == now.year && nextMonth.month > now.month)) return;
    setState(() {
      _displayedMonth = nextMonth;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final now = DateTime.now();
    final isCurrentMonth = year == now.year && month == now.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              tooltip: l10n.calendar_prev_month,
              onPressed: _previousMonth,
              visualDensity: VisualDensity.compact,
            ),
            Text(
              l10n.calendar_year_month(year, month),
              style: AppTypography.heading.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                size: 20,
                color: isCurrentMonth
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2)
                    : null,
              ),
              tooltip: l10n.calendar_next_month,
              onPressed: isCurrentMonth ? null : _nextMonth,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Weekday headers
        Row(
          children: l10n.calendar_weekdays.split(',')
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: AppTypography.caption.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Calendar grid
        _buildGrid(context, year, month, daysInMonth),
      ],
    );
  }

  Widget _buildGrid(
      BuildContext context, int year, int month, int daysInMonth) {
    // First day of month: weekday (1=Mon, 7=Sun)
    final firstWeekday = DateTime(year, month, 1).weekday;
    final leadingBlanks = firstWeekday - 1; // Mon-indexed

    final cells = <Widget>[];

    // Leading blanks
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final hasRecording = widget.recordedDates.contains(date);
      final isSelected = widget.selectedDate != null &&
          widget.selectedDate!.year == date.year &&
          widget.selectedDate!.month == date.month &&
          widget.selectedDate!.day == date.day;

      cells.add(
        GestureDetector(
          onTap: () => widget.onDateSelected(date),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2)
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: hasRecording ? 0.9 : 0.4),
                    ),
                  ),
                  if (hasRecording)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Build rows of 7
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final end = (i + 7).clamp(0, cells.length);
      final rowCells = cells.sublist(i, end);
      // Pad last row
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox());
      }
      rows.add(
        SizedBox(
          height: 40,
          child: Row(
            children: rowCells
                .map((c) => Expanded(child: c))
                .toList(),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}
