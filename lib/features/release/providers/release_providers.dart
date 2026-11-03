// 手放す（release）機能の Riverpod プロバイダー。
//
// ── main.dart への配線（WP3b が行う。ここでは main.dart を編集しない）────────────────
//   import 'features/release/data/release_db.dart';
//   import 'features/release/providers/release_providers.dart';
//
//   await Hive.initFlutter();                 // 既存
//   final localDb = LocalDb(); await localDb.init();   // 既存
//   final releaseDb = ReleaseDb();
//   await releaseDb.init();                   // ← 追加（4 つの Hive 箱を開く）
//   ...
//   ProviderScope(overrides: [
//     localDbProvider.overrideWithValue(localDb),       // 既存
//     releaseDbProvider.overrideWithValue(releaseDb),   // ← 追加（必須。無いと StateError）
//     ...
//   ])
//
// アカウント削除（settings_provider.dart の deleteAccountData）では
//   await ref.read(releaseDbProvider).clearAll();
// を呼んで 4 箱すべてを消し、ref.invalidate(releaseSettingsProvider) する。
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_provider.dart';
import '../data/content_repository.dart';
import '../data/dialogue_repository.dart';
import '../data/release_db.dart';
import '../data/release_domain.dart';
import '../data/release_repository.dart';
import '../data/release_settings_repository.dart';
import '../domain/crisis_logic.dart';
import '../domain/models.dart';
import '../domain/records.dart';
import '../domain/release_settings.dart';
import '../domain/release_tools.dart';
import '../domain/today_pick.dart';
import '../domain/weekly_letter.dart';

/// main() で ReleaseDb.init() の後に必ず override する。
final releaseDbProvider = Provider<ReleaseDb>((ref) {
  throw StateError('releaseDbProvider must be overridden in main() after ReleaseDb.init()');
});

/// 現在時刻（epoch millis）。テストで差し替える。
final releaseClockProvider = Provider<int Function()>((ref) {
  return () => DateTime.now().millisecondsSinceEpoch;
});

/// アセットの読み手（テストでは File から読む実装に差し替える）。
final contentAssetLoaderProvider = Provider<ContentAssetLoader>((ref) {
  return const RootBundleContentLoader();
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.watch(contentAssetLoaderProvider));
});

/// 全コンテンツ（初回だけ読み込み、以後キャッシュ）。
final releaseContentProvider = FutureProvider<LoadedContent>((ref) {
  return ref.watch(contentRepositoryProvider).bundle();
});

final releaseSettingsRepositoryProvider = Provider<ReleaseSettingsRepository>((ref) {
  return ReleaseSettingsRepository(ref.watch(releaseDbProvider));
});

final releaseRepositoryProvider = Provider<ReleaseRepository>((ref) {
  return ReleaseRepository(ref.watch(releaseDbProvider), now: ref.watch(releaseClockProvider));
});

final dialogueRepositoryProvider = Provider<DialogueRepository>((ref) {
  return DialogueRepository(
    content: ref.watch(contentRepositoryProvider),
    db: ref.watch(releaseDbProvider),
    settings: ref.watch(releaseSettingsRepositoryProvider),
    now: ref.watch(releaseClockProvider),
  );
});

/// SafetyGate / OutputGate / CardSelector / ReplayReminder / DialogueEngine の束。
final releaseDomainProvider = FutureProvider<ReleaseDomain>((ref) {
  return ref.watch(dialogueRepositoryProvider).domain();
});

/// コンテンツ言語（Voxna の表示言語に合わせる。'system' なら端末の言語、対応外は en）。
final releaseContentLangProvider = Provider<AppLang>((ref) {
  final code = ref.watch(settingsProvider.select((s) => s.localeCode));
  // 端末の言語リストの先頭から、対応している最初のもの（Flutter の表示言語の選び方に合わせる）。
  final locales = PlatformDispatcher.instance.locales;
  final supported = locales.map((l) => l.languageCode).where((c) => AppLang.fromTag(c) != null);
  final system = supported.isNotEmpty ? supported.first : PlatformDispatcher.instance.locale.languageCode;
  return contentLangFor(code, system);
});

// ---- 設定 ----

/// 手放す系の設定。state は不変の [ReleaseSettings]。変更はメソッド経由（Hive に保存される）。
class ReleaseSettingsNotifier extends Notifier<ReleaseSettings> {
  ReleaseSettingsRepository get _repo => ref.read(releaseSettingsRepositoryProvider);

  @override
  ReleaseSettings build() {
    final repo = ref.watch(releaseSettingsRepositoryProvider);
    // 他の経路（DialogueRepository の lastCrisisAt・直近 id など）が保存した値も反映する。
    final sub = repo.watch().listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return repo.current;
  }

  Future<void> _apply(Future<ReleaseSettings> Function(ReleaseSettingsRepository r) change) async {
    state = await change(_repo);
  }

  Future<void> setTtsEnabled(bool v) => _apply((r) => r.setTtsEnabled(v));
  Future<void> setHapticsEnabled(bool v) => _apply((r) => r.setHapticsEnabled(v));
  Future<void> setGoalCount(int v) => _apply((r) => r.setGoalCount(v));
  Future<void> setLoopSpeed(LoopSpeed v) => _apply((r) => r.setLoopSpeed(v.settingValue));
  Future<void> setBreathPattern(int breathIn, int breathHold, int breathOut) =>
      _apply((r) => r.setBreathPattern(breathIn, breathHold, breathOut));
  Future<void> setQuietHours(String start, String end) => _apply((r) => r.setQuietHours(start, end));
  Future<void> setPauseUntil(int epochMillis) => _apply((r) => r.setPauseUntil(epochMillis));

  /// 通知を 1 週間お休みする。
  Future<void> pauseOneWeek() => _apply(
      (r) => r.setPauseUntil(ref.read(releaseClockProvider)() + const Duration(days: 7).inMilliseconds));
  Future<void> cancelPause() => _apply((r) => r.setPauseUntil(0));
  Future<void> setReplayMode(ReplayMode v) => _apply((r) => r.setReplayMode(v));

  /// 初回の説明に同意した（今の時刻を記録）。
  Future<void> acceptDisclaimer() =>
      _apply((r) => r.setDisclaimerAcceptedAt(ref.read(releaseClockProvider)()));
  Future<void> setCustomWords(List<String> words) => _apply((r) => r.setCustomWords(words));
  Future<void> setReleaseTool(String id) => _apply((r) => r.setReleaseTool(id));
  Future<void> setOwnTools(List<String> tools) => _apply((r) => r.setOwnTools(tools));
  Future<void> setKeepNotes(bool v) => _apply((r) => r.setKeepNotes(v));
  Future<void> setTriggerCues(List<TriggerCue> cues) => _apply((r) => r.setTriggerCues(cues));
  Future<void> setTriggerSentence(String v) => _apply((r) => r.setTriggerSentence(v));
  Future<void> setCheckinMorning({bool? enabled, String? time}) =>
      _apply((r) => r.setCheckinMorning(enabled: enabled, time: time));
  Future<void> setCheckinEvening({bool? enabled, String? time}) =>
      _apply((r) => r.setCheckinEvening(enabled: enabled, time: time));
  Future<void> setZeroDay({bool? enabled, String? time}) =>
      _apply((r) => r.setZeroDay(enabled: enabled, time: time));
  Future<void> pushRecentCardId(String id) => _apply((r) => r.pushRecentCardId(id));
  Future<void> pushRecentReplayId(String id) => _apply((r) => r.pushRecentReplayId(id));

  /// 他の経路（DialogueRepository 等）が保存した値を読み直す。
  void reload() => state = _repo.current;
}

final releaseSettingsProvider = NotifierProvider<ReleaseSettingsNotifier, ReleaseSettings>(
  ReleaseSettingsNotifier.new,
);

// ---- 記録（Hive の変更で自動更新） ----

/// セッション・あとで手放すが変わるたびに [read] を計算し直して流す。
Stream<T> _live<T>(Ref ref, T Function(ReleaseRepository repo) read) async* {
  final repo = ref.watch(releaseRepositoryProvider);
  yield read(repo);
  await for (final _ in repo.watch()) {
    yield read(repo);
  }
}

/// 今月の回数・7 日の点灯・おかえり・今日の回数。
final releaseSummaryProvider = StreamProvider<ReleaseSummary>((ref) {
  return _live(ref, (r) => r.summary());
});

/// 残した内容の記録（最後に手放した順）。
final releaseRecordsProvider = StreamProvider<List<ReleaseSession>>((ref) {
  return _live(ref, (r) => r.records());
});

/// 未処理の「あとで手放す」。
final releasePendingProvider = StreamProvider<List<PendingEvent>>((ref) {
  return _live(ref, (r) => r.pendingEvents());
});

/// よく手放した記憶（最大 8 件）。
final releaseFrequentTagsProvider = StreamProvider<List<({String tag, int count})>>((ref) {
  return _live(ref, (r) => r.frequentTags());
});

/// 今週の手紙（1 回も無ければ null）。
final releaseWeeklyStatsProvider = StreamProvider<WeeklyStats?>((ref) {
  return _live(ref, (r) => r.weeklyStats());
});

/// その月（[DateTime] の年月）の日別の手放した回数。キーはローカル日付 0 時。
final releaseCountsByMonthProvider =
    StreamProvider.family<Map<DateTime, int>, DateTime>((ref, month) {
  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0);
  return _live(ref, (r) => r.countsByDay(from, to));
});

// ---- 今日の一枚・危機バナー ----

/// 今日の一枚（語 + 一文）。言語・手放す言葉が変わると作り直す。
final releaseTodayCardProvider = FutureProvider<TodayCard>((ref) async {
  final lang = ref.watch(releaseContentLangProvider);
  final custom = ref.watch(releaseSettingsProvider.select((s) => s.customWords));
  final repo = ref.watch(contentRepositoryProvider);
  final now = ref.watch(releaseClockProvider)();
  return TodayPick.card(
    words: await repo.words(lang),
    customWords: custom,
    today: await repo.today(lang),
    date: DateTime.fromMillisecondsSinceEpoch(now),
  );
});

/// 危機バナーを出すか（最後の危機判定から 24 時間）。
final releaseCrisisBannerProvider = Provider<bool>((ref) {
  final last = ref.watch(releaseSettingsProvider.select((s) => s.lastCrisisAt));
  return CrisisLogic.isBannerVisible(last, ref.watch(releaseClockProvider)());
});

/// その言語で自由入力（対話・書く）を出してよいか（危機辞書がある言語だけ）。
final releaseFreeTextAllowedProvider = FutureProvider<bool>((ref) {
  final lang = ref.watch(releaseContentLangProvider);
  return ref.watch(dialogueRepositoryProvider).isFreeTextAllowed(lang);
});

/// 手放しシーンの言葉の組（言語と「手放す言葉」に追従）。
final releaseWordSetProvider = FutureProvider<ReleaseWordSet>((ref) async {
  final lang = ref.watch(releaseContentLangProvider);
  final custom = ref.watch(releaseSettingsProvider.select((s) => s.customWords));
  final words = await ref.watch(contentRepositoryProvider).words(lang);
  return ReleaseWordSet.build(words, custom);
});
