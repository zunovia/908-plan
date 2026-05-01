import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/storage_providers.dart';
import '../../recording/data/recording_model.dart';
import '../data/daily_prompts.dart';
import '../presentation/widgets/duration_selector.dart';

class HomeState {
  final int dayCount;
  final int streak;
  final String dailyPrompt;
  final RecordingDuration selectedDuration;
  final List<RecordingModel> recentRecordings;
  final bool hasEnoughData;

  const HomeState({
    this.dayCount = 0,
    this.streak = 0,
    this.dailyPrompt = '',
    this.selectedDuration = RecordingDuration.normal30,
    this.recentRecordings = const [],
    this.hasEnoughData = false,
  });

  HomeState copyWith({
    int? dayCount,
    int? streak,
    String? dailyPrompt,
    RecordingDuration? selectedDuration,
    List<RecordingModel>? recentRecordings,
    bool? hasEnoughData,
  }) {
    return HomeState(
      dayCount: dayCount ?? this.dayCount,
      streak: streak ?? this.streak,
      dailyPrompt: dailyPrompt ?? this.dailyPrompt,
      selectedDuration: selectedDuration ?? this.selectedDuration,
      recentRecordings: recentRecordings ?? this.recentRecordings,
      hasEnoughData: hasEnoughData ?? this.hasEnoughData,
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  @override
  HomeState build() {
    return _loadData(const HomeState());
  }

  HomeState _loadData(HomeState current) {
    final repo = ref.read(localRecordingRepositoryProvider);

    final recordings = repo.getRecordings();
    final dayCount = repo.getUniqueDayCount();
    final streak = _computeStreak(recordings);
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentRecordings = repo.getRecordingsInRange(
      sevenDaysAgo,
      now.add(const Duration(days: 1)),
    );

    return current.copyWith(
      dayCount: dayCount,
      streak: streak,
      dailyPrompt: getDailyPrompt(dayCount),
      recentRecordings: recentRecordings,
      hasEnoughData: dayCount >= 7,
    );
  }

  int _computeStreak(List<RecordingModel> recordings) =>
      computeStreak(recordings);

  void setDuration(RecordingDuration duration) {
    state = state.copyWith(selectedDuration: duration);
  }

  void refreshData() {
    state = _loadData(state);
  }
}

/// Compute consecutive recording streak from today backwards.
/// Visible for testing.
int computeStreak(List<RecordingModel> recordings) {
  if (recordings.isEmpty) return 0;

  final days = recordings
      .map((r) => DateTime(r.recordedAt.year, r.recordedAt.month, r.recordedAt.day))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  final today = DateTime.now();
  final todayNorm = DateTime(today.year, today.month, today.day);

  // If the most recent day is not today or yesterday, streak is 0
  final gap = todayNorm.difference(days.first).inDays;
  if (gap > 1) return 0;

  int streak = 1;
  for (int i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
