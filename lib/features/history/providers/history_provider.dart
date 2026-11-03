import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/storage_providers.dart';
import '../../recording/data/recording_model.dart';
import '../../release/providers/release_providers.dart';

class HistoryState {
  final Set<DateTime> recordedDates;
  final DateTime? selectedDate;
  final List<RecordingModel> selectedDateRecordings;

  const HistoryState({
    this.recordedDates = const {},
    this.selectedDate,
    this.selectedDateRecordings = const [],
  });

  HistoryState copyWith({
    Set<DateTime>? recordedDates,
    Object? selectedDate = _sentinel,
    List<RecordingModel>? selectedDateRecordings,
  }) {
    return HistoryState(
      recordedDates: recordedDates ?? this.recordedDates,
      selectedDate: selectedDate == _sentinel
          ? this.selectedDate
          : selectedDate as DateTime?,
      selectedDateRecordings:
          selectedDateRecordings ?? this.selectedDateRecordings,
    );
  }

  static const _sentinel = Object();
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    Future.microtask(_loadRecordedDates);
    return const HistoryState();
  }

  void _loadRecordedDates() {
    final repo = ref.read(localRecordingRepositoryProvider);
    final recordings = repo.getRecordings();
    final dates = <DateTime>{};
    for (final r in recordings) {
      dates.add(DateTime(
        r.recordedAt.year,
        r.recordedAt.month,
        r.recordedAt.day,
      ));
    }
    state = state.copyWith(recordedDates: dates);
  }

  void selectDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final repo = ref.read(localRecordingRepositoryProvider);
    final dayStart = normalized;
    final dayEnd = normalized.add(const Duration(days: 1));
    final recordings = repo.getRecordingsInRange(dayStart, dayEnd);

    state = state.copyWith(
      selectedDate: normalized,
      selectedDateRecordings: recordings,
    );
  }

  void refresh() {
    _loadRecordedDates();
    if (state.selectedDate != null) {
      selectDate(state.selectedDate!);
    }
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(
  HistoryNotifier.new,
);

/// Number of releases (手放した回数) per local day, for the calendar dots and
/// the day detail. Keys are local midnight `DateTime(y, m, d)`. Updates when
/// a release session is saved or deleted.
final historyReleaseCountsProvider = StreamProvider<Map<DateTime, int>>((ref) async* {
  final repo = ref.watch(releaseRepositoryProvider);
  Map<DateTime, int> read() => repo.countsByDay(DateTime(2000), repo.today());
  yield read();
  await for (final _ in repo.watch()) {
    yield read();
  }
});
