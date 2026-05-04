import 'dart:ui';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/insights/insight_engine.dart';
import '../../../core/providers/storage_providers.dart';
import '../../recording/data/recording_model.dart';
import '../../settings/providers/settings_provider.dart';
import '../data/report_model.dart';

class ReportState {
  final String dateRange;
  final bool isLoading;
  final List<DailyMetric> metrics;
  final String? highlight;
  final String? inquiry;

  const ReportState({
    this.dateRange = '',
    this.isLoading = false,
    this.metrics = const [],
    this.highlight,
    this.inquiry,
  });

  bool get hasData => metrics.isNotEmpty;

  ReportState copyWith({
    String? dateRange,
    bool? isLoading,
    List<DailyMetric>? metrics,
    String? highlight,
    String? inquiry,
  }) {
    return ReportState(
      dateRange: dateRange ?? this.dateRange,
      isLoading: isLoading ?? this.isLoading,
      metrics: metrics ?? this.metrics,
      highlight: highlight ?? this.highlight,
      inquiry: inquiry ?? this.inquiry,
    );
  }
}

// --- Weekly ---

class ReportNotifier extends Notifier<ReportState> {
  @override
  ReportState build() {
    final localeCode = ref.watch(
      settingsProvider.select((s) => s.localeCode),
    );
    Future.microtask(() => _loadWeeklyReport(localeCode));
    return const ReportState(isLoading: true);
  }

  void _loadWeeklyReport(String localeCode) async {
    final resolvedLocale = localeCode == 'system'
        ? PlatformDispatcher.instance.locale
        : Locale(localeCode);
    final l10n = await AppLocalizations.delegate.load(resolvedLocale);

    final repo = ref.read(localRecordingRepositoryProvider);
    final now = DateTime.now();

    final weekday = now.weekday;
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final recordings = repo.getRecordingsInRange(weekStart, weekEnd);
    final dailyMetrics = _aggregateByDay(recordings, weekStart, 7);

    final highlight = InsightEngine.generateHighlight(dailyMetrics, l10n);
    final dateFormat = DateFormat('M/d');
    final dateRange =
        '${dateFormat.format(weekStart)} - ${dateFormat.format(weekEnd.subtract(const Duration(days: 1)))}';

    final inquiry = InsightEngine.generateWeeklyInquiry(dailyMetrics, l10n);

    state = ReportState(
      dateRange: dateRange,
      isLoading: false,
      metrics: dailyMetrics,
      highlight: highlight,
      inquiry: inquiry,
    );
  }

  void refresh() {
    final localeCode = ref.read(settingsProvider).localeCode;
    _loadWeeklyReport(localeCode);
  }
}

final reportProvider = NotifierProvider<ReportNotifier, ReportState>(
  ReportNotifier.new,
);

// --- Monthly ---

class MonthlyReportNotifier extends Notifier<ReportState> {
  @override
  ReportState build() {
    final localeCode = ref.watch(
      settingsProvider.select((s) => s.localeCode),
    );
    Future.microtask(() => _loadMonthlyReport(localeCode));
    return const ReportState(isLoading: true);
  }

  void _loadMonthlyReport(String localeCode) async {
    final resolvedLocale = localeCode == 'system'
        ? PlatformDispatcher.instance.locale
        : Locale(localeCode);
    final l10n = await AppLocalizations.delegate.load(resolvedLocale);

    final repo = ref.read(localRecordingRepositoryProvider);
    final now = DateTime.now();

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = monthEnd.difference(monthStart).inDays;

    final recordings = repo.getRecordingsInRange(monthStart, monthEnd);
    final dailyMetrics = _aggregateByDay(recordings, monthStart, daysInMonth);

    final highlight = InsightEngine.generateHighlight(dailyMetrics, l10n);
    final dateRange = l10n.report_date_range_monthly(now.year, now.month);

    // Compare with previous month
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevRecordings =
        repo.getRecordingsInRange(prevMonthStart, monthStart);
    final comparison =
        InsightEngine.generateMonthlyComparison(dailyMetrics, prevRecordings, l10n);

    state = ReportState(
      dateRange: dateRange,
      isLoading: false,
      metrics: dailyMetrics,
      highlight: highlight,
      inquiry: comparison,
    );
  }

  void refresh() {
    final localeCode = ref.read(settingsProvider).localeCode;
    _loadMonthlyReport(localeCode);
  }
}

final monthlyReportProvider =
    NotifierProvider<MonthlyReportNotifier, ReportState>(
  MonthlyReportNotifier.new,
);

// --- Shared helpers ---

List<DailyMetric> _aggregateByDay(
  List<RecordingModel> recordings,
  DateTime start,
  int dayCount,
) {
  final metricsByDay = <String, List<_MetricAccumulator>>{};
  for (final r in recordings) {
    final dayKey =
        '${r.recordedAt.year}-${r.recordedAt.month}-${r.recordedAt.day}';
    metricsByDay.putIfAbsent(dayKey, () => []);
    metricsByDay[dayKey]!.add(_MetricAccumulator(
      energy: r.energy ?? 0.5,
      clarity: r.clarity ?? 0.5,
      expressionRange: r.expressionRange ?? 0.5,
      tempo: r.tempo ?? 3.0,
    ));
  }

  final dailyMetrics = <DailyMetric>[];
  for (var i = 0; i < dayCount; i++) {
    final day = start.add(Duration(days: i));
    final dayKey = '${day.year}-${day.month}-${day.day}';
    final dayRecordings = metricsByDay[dayKey];

    if (dayRecordings != null && dayRecordings.isNotEmpty) {
      final avgEnergy =
          dayRecordings.map((m) => m.energy).reduce((a, b) => a + b) /
              dayRecordings.length;
      final avgClarity =
          dayRecordings.map((m) => m.clarity).reduce((a, b) => a + b) /
              dayRecordings.length;
      final avgExpression =
          dayRecordings
                  .map((m) => m.expressionRange)
                  .reduce((a, b) => a + b) /
              dayRecordings.length;
      final avgTempo =
          dayRecordings.map((m) => m.tempo).reduce((a, b) => a + b) /
              dayRecordings.length;

      dailyMetrics.add(DailyMetric(
        date: day,
        energy: avgEnergy,
        clarity: avgClarity,
        expressionRange: avgExpression,
        tempo: avgTempo,
      ));
    }
  }
  return dailyMetrics;
}

class _MetricAccumulator {
  final double energy;
  final double clarity;
  final double expressionRange;
  final double tempo;

  const _MetricAccumulator({
    required this.energy,
    required this.clarity,
    required this.expressionRange,
    required this.tempo,
  });
}
