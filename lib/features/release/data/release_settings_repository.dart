// 手放す系の設定（Hive release_settings の 1 件に Map で保存）。Luckarise の SettingsRepository に対応。

import 'dart:async';

import '../domain/models.dart';
import '../domain/own_tools.dart';
import '../domain/release_settings.dart';
import 'release_db.dart';

class ReleaseSettingsRepository {
  ReleaseSettingsRepository(this._db);

  final ReleaseDb _db;
  final StreamController<ReleaseSettings> _changes = StreamController<ReleaseSettings>.broadcast();

  /// 今の設定（保存が無ければ既定値）。同期で読める。
  ReleaseSettings get current =>
      ReleaseSettings.fromMap(_db.settings.get(ReleaseDb.settingsKey));

  /// 保存のたびに新しい設定を流す（broadcast）。
  Stream<ReleaseSettings> watch() => _changes.stream;

  Future<void> save(ReleaseSettings settings) async {
    await _db.settings.put(ReleaseDb.settingsKey, settings.toMap());
    _changes.add(settings);
  }

  /// 今の設定を [change] で変えて保存し、保存後の設定を返す。
  Future<ReleaseSettings> update(ReleaseSettings Function(ReleaseSettings) change) async {
    final next = change(current);
    await save(next);
    return next;
  }

  Future<ReleaseSettings> setTtsEnabled(bool v) => update((s) => s.copyWith(ttsEnabled: v));
  Future<ReleaseSettings> setHapticsEnabled(bool v) => update((s) => s.copyWith(hapticsEnabled: v));
  Future<ReleaseSettings> setGoalCount(int v) => update((s) => s.copyWith(goalCount: v));

  /// "off" / "slow" / "normal" / "fast"。
  Future<ReleaseSettings> setLoopSpeed(String v) => update((s) => s.copyWith(loopSpeed: v));
  Future<ReleaseSettings> setBreathPattern(int breathIn, int breathHold, int breathOut) =>
      update((s) => s.copyWith(breathIn: breathIn, breathHold: breathHold, breathOut: breathOut));

  /// 静音時間（"HH:mm"）。
  Future<ReleaseSettings> setQuietHours(String start, String end) =>
      update((s) => s.copyWith(quietStart: start, quietEnd: end));
  Future<ReleaseSettings> setPauseUntil(int epochMillis) =>
      update((s) => s.copyWith(pauseUntil: epochMillis));
  Future<ReleaseSettings> setReplayMode(ReplayMode v) => update((s) => s.copyWith(replayMode: v));
  Future<ReleaseSettings> setDisclaimerAcceptedAt(int? epochMillis) =>
      update((s) => s.copyWith(disclaimerAcceptedAt: epochMillis));
  Future<ReleaseSettings> setLastCrisisAt(int epochMillis) =>
      update((s) => s.copyWith(lastCrisisAt: epochMillis));

  Future<ReleaseSettings> pushRecentReplayId(String id) =>
      update((s) => s.copyWith(recentReplayIds: RecentIds.push(s.recentReplayIds, id)));
  Future<ReleaseSettings> pushRecentCardId(String id) =>
      update((s) => s.copyWith(recentCardIds: RecentIds.push(s.recentCardIds, id)));
  Future<ReleaseSettings> pushRecentReflectionId(String id) =>
      update((s) => s.copyWith(recentReflectionIds: RecentIds.push(s.recentReflectionIds, id)));

  /// 「手放す言葉」（空・前後の空白を除き、最大 8 語・1 語 24 文字）。空リストで既定に戻す。
  Future<ReleaseSettings> setCustomWords(List<String> words) =>
      update((s) => s.copyWith(customWords: CustomWords.normalize(words)));

  /// ツール（ReleaseTools の id）。
  Future<ReleaseSettings> setReleaseTool(String id) => update((s) => s.copyWith(releaseTool: id));

  /// 自分でつくったツール（正規化して最大 10 個）。
  Future<ReleaseSettings> setOwnTools(List<String> tools) =>
      update((s) => s.copyWith(ownTools: OwnTools.normalize(tools)));
  Future<ReleaseSettings> setKeepNotes(bool v) => update((s) => s.copyWith(keepNotes: v));
  Future<ReleaseSettings> setTriggerCues(List<TriggerCue> cues) =>
      update((s) => s.copyWith(triggerCues: TriggerCue.decode(TriggerCue.encode(cues))));

  /// 本人の一文（前後の空白を除き 60 文字まで）。
  Future<ReleaseSettings> setTriggerSentence(String v) {
    final t = v.trim();
    return update((s) => s.copyWith(triggerSentence: t.length > 60 ? t.substring(0, 60) : t));
  }

  Future<ReleaseSettings> setCheckinMorning({bool? enabled, String? time}) => update(
      (s) => s.copyWith(checkinMorningEnabled: enabled, checkinMorningTime: time));
  Future<ReleaseSettings> setCheckinEvening({bool? enabled, String? time}) => update(
      (s) => s.copyWith(checkinEveningEnabled: enabled, checkinEveningTime: time));
  Future<ReleaseSettings> setZeroDay({bool? enabled, String? time}) =>
      update((s) => s.copyWith(zeroDayEnabled: enabled, zeroDayTime: time));

  /// 既定値に戻す（箱から設定を消す）。
  Future<void> reset() async {
    await _db.settings.delete(ReleaseDb.settingsKey);
    _changes.add(const ReleaseSettings());
  }
}
