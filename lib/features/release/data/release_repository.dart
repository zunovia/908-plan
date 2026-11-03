// 手放しの記録（セッション・あとで手放す）。Luckarise の data/repo/PracticeRepository.kt を移植。
// 「今日」の境界は端末ローカルの 0 時。セッションを最初のタップで作る・0 回なら破棄する、は UI 側の責務。

import 'dart:async';
import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../domain/models.dart';
import '../domain/records.dart';
import '../domain/weekly_letter.dart';
import 'release_db.dart';

/// 回数まわりの要約（手放すタブ・完了画面で共通）。
class ReleaseSummary {
  const ReleaseSummary({
    required this.monthCount,
    required this.last7,
    required this.welcomeBack,
    required this.hasAny,
    required this.todayCount,
  });

  static const ReleaseSummary empty = ReleaseSummary(
    monthCount: 0,
    last7: [false, false, false, false, false, false, false],
    welcomeBack: false,
    hasAny: false,
    todayCount: 0,
  );

  /// 今月手放した回数（完了したセッションの数）。
  final int monthCount;

  /// 最近 7 日の点灯（古い順、最後が今日）。
  final List<bool> last7;

  /// 3 日以上空いたあと今日手放した（「おかえり」）。
  final bool welcomeBack;

  /// 1 回でも手放したことがある。
  final bool hasAny;

  /// 今日唱えた回数の合計（危機を除く今日開始のセッションの count 合計）。
  final int todayCount;
}

/// 「もう一度手放す」のときに書く画面へ渡す元の記録の内容。
class ReleaseDraft {
  const ReleaseDraft({required this.sourceSessionId, this.note, this.tags = const [], this.scene});

  final String sourceSessionId;
  final String? note;
  final List<String> tags;
  final String? scene;
}

class ReleaseRepository {
  ReleaseRepository(this._db, {int Function()? now, String Function()? newId})
      : _now = now ?? _systemNow,
        _newId = newId ?? _randomId;

  final ReleaseDb _db;
  final int Function() _now;
  final String Function() _newId;

  static int _systemNow() => DateTime.now().millisecondsSinceEpoch;

  static final Random _rnd = Random.secure();
  static String _randomId() {
    final sb = StringBuffer(DateTime.now().microsecondsSinceEpoch.toRadixString(36));
    for (var i = 0; i < 4; i++) {
      sb.write(_rnd.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'));
    }
    return sb.toString();
  }

  int nowMillis() => _now();

  /// 今日（ローカル日付）。
  DateTime today() {
    final n = DateTime.fromMillisecondsSinceEpoch(_now());
    return DateTime(n.year, n.month, n.day);
  }

  /// 今が夜（0〜5 時）か。
  bool isNight() => TimeRules.isNightHour(DateTime.fromMillisecondsSinceEpoch(_now()).hour);

  // ---- 変更の通知 ----

  /// セッション・あとで手放すが変わるたびに流れる（購読中だけ Hive を見張る）。
  Stream<void> watch() {
    StreamSubscription<BoxEvent>? a;
    StreamSubscription<BoxEvent>? b;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () {
        a = _db.sessions.watch().listen((_) => controller.add(null));
        b = _db.pending.watch().listen((_) => controller.add(null));
      },
      onCancel: () async {
        await a?.cancel();
        await b?.cancel();
      },
    );
    return controller.stream;
  }

  // ---- セッション ----

  /// セッションを作る（count=0・未完了）。本文は前後の空白を除き、空なら保存しない。
  Future<String> startSession({
    required SessionKind kind,
    EmotionTag? emotion,
    String? cardId,
    int? moodBefore,
    SessionTrigger trigger = SessionTrigger.MANUAL,
    String? note,
    List<String> tags = const [],
    String? scene,
    String? sourceSessionId,
    int? occurredAt,
    String? voiceRecordingId,
  }) async {
    final id = _newId();
    final normalized = ReleaseSession.normalizeTags(tags);
    final trimmedNote = note?.trim();
    final s = ReleaseSession(
      id: id,
      startedAt: _now(),
      kind: kind,
      count: 0,
      moodBefore: moodBefore,
      emotion: emotion,
      cardId: cardId,
      memoryLabel: normalized.isEmpty ? null : normalized.first,
      trigger: trigger,
      occurredAt: occurredAt,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
      memoryTags: normalized,
      scene: (scene == null || scene.trim().isEmpty) ? null : scene,
      sourceSessionId: sourceSessionId,
      voiceRecordingId: voiceRecordingId,
    );
    await _db.sessions.put(id, s.toMap());
    return id;
  }

  /// セッションを完了にする（終了時刻・回数・気分・最後に手放した時刻）。
  /// 「もう一度手放す」から来た場合は元の記録の releaseCount を +1 する。
  Future<void> finishSession(String id, int count, {int? moodAfter, String? memoryLabel}) async {
    final existing = sessionById(id);
    if (existing == null) return;
    final now = _now();
    await _db.sessions.put(
      id,
      existing
          .copyWith(
            endedAt: now,
            count: count,
            moodAfter: moodAfter,
            memoryLabel: memoryLabel ?? existing.memoryLabel,
            lastReleasedAt: now,
          )
          .toMap(),
    );
    final sourceId = existing.sourceSessionId;
    if (sourceId != null) {
      final source = sessionById(sourceId);
      if (source != null) {
        await _db.sessions.put(
          sourceId,
          source.copyWith(releaseCount: source.releaseCount + 1, lastReleasedAt: now).toMap(),
        );
      }
    }
  }

  Future<void> setMoodAfter(String id, int? moodAfter) async {
    final s = sessionById(id);
    if (s == null) return;
    await _db.sessions.put(id, s.copyWith(moodAfter: moodAfter).toMap());
  }

  Future<void> setMemoryLabel(String id, String? memoryLabel) async {
    final s = sessionById(id);
    if (s == null) return;
    await _db.sessions.put(id, s.copyWith(memoryLabel: memoryLabel).toMap());
  }

  /// [startSession] で作った行を、実践せずに終えた（0 回）等の理由で保存しない場合に消す。
  Future<void> discardSession(String id) => _db.sessions.delete(id);

  /// アプリが手放しの途中で終了させられて残った行（未完了・0 回・危機でない）を消す。
  /// 書いた本文が見えないまま端末に残らないようにする。[olderThanMillis] より前に始まったものだけ。
  Future<int> purgeAbandoned({int olderThanMillis = 6 * 60 * 60 * 1000}) async {
    final limit = _now() - olderThanMillis;
    final keys = <dynamic>[];
    for (final key in _db.sessions.keys) {
      final raw = _db.sessions.get(key);
      if (raw == null) continue;
      final s = ReleaseSession.fromMap(raw);
      if (!s.crisis && s.endedAt == null && s.count == 0 && s.startedAt < limit) keys.add(key);
    }
    if (keys.isNotEmpty) await _db.sessions.deleteAll(keys);
    return keys.length;
  }

  /// 記録を削除する（元の記録と、それを「もう一度手放す」で手放した行の両方）。
  Future<void> deleteRecord(String id) async {
    final keys = <dynamic>[];
    for (final key in _db.sessions.keys) {
      final raw = _db.sessions.get(key);
      if (raw == null) continue;
      final s = ReleaseSession.fromMap(raw);
      if (s.id == id || s.sourceSessionId == id) keys.add(key);
    }
    await _db.sessions.deleteAll(keys);
  }

  ReleaseSession? sessionById(String id) {
    final raw = _db.sessions.get(id);
    return raw == null ? null : ReleaseSession.fromMap(raw);
  }

  /// 「もう一度手放す」: 元の記録の本文・チップ・場面（書く画面の初期値）。
  /// UI はこのあと startSession(sourceSessionId: draft.sourceSessionId, ...) で新しい回を作り、
  /// finishSession で元の記録の回数が +1 される。
  ReleaseDraft? releaseAgainDraft(String sourceSessionId) {
    final s = sessionById(sourceSessionId);
    if (s == null) return null;
    return ReleaseDraft(sourceSessionId: s.id, note: s.note, tags: s.memoryTags, scene: s.scene);
  }

  /// 全セッション（開始の新しい順）。危機・未完了を含む。
  List<ReleaseSession> allSessions() {
    final list = _db.sessions.values.map(ReleaseSession.fromMap).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  /// 完了した実践（危機を除く・回数 > 0・終了済み）。開始の新しい順。
  List<ReleaseSession> completedSessions() => allSessions().where((s) => s.isCompleted).toList();

  /// 完了した実践の通算回数。
  int completedTotal() => completedSessions().length;

  /// 残した内容の記録（本文あり・「もう一度」の子を除く）。最後に手放した順。
  List<ReleaseSession> records() {
    final list = allSessions().where((s) => s.isRecord).toList()
      ..sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return list;
  }

  /// 記録の絞り込みに使えるチップ（記録に付いているチップ・場面を多い順）。
  static List<String> recordFilterTags(List<ReleaseSession> records) {
    final counts = <String, int>{};
    for (final r in records) {
      for (final t in [...r.memoryTags, if (r.scene != null) r.scene!]) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return _sortedByCountDesc(counts).map((e) => e.key).toList();
  }

  /// [from] 以上 [to] 以下（epoch millis）に開始したセッション（新しい順）。
  List<ReleaseSession> sessionsBetween(int from, int to) =>
      allSessions().where((s) => s.startedAt >= from && s.startedAt <= to).toList();

  /// その日（ローカル）に開始したセッション。
  List<ReleaseSession> sessionsOnDay(DateTime day) {
    final from = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final to = DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch - 1;
    return sessionsBetween(from, to);
  }

  /// 最後に手放した（完了した）時刻。無ければ null。
  int? lastSessionAt() {
    int? last;
    for (final s in completedSessions()) {
      final at = s.endedAt ?? s.startedAt;
      if (last == null || at > last) last = at;
    }
    return last;
  }

  // ---- 集計 ----

  /// 完了セッションを「実践 1 回」の印にしたもの（手紙・点灯・回数の元データ）。
  List<PracticeMark> marks() => completedSessions()
      .map((s) => PracticeMark(DateTime.fromMillisecondsSinceEpoch(s.startedAt), s.memoryTags))
      .toList();

  ReleaseSummary summary() {
    final list = marks();
    final t = today();
    return ReleaseSummary(
      monthCount: WeeklyLetter.monthCount(list, t),
      last7: WeeklyLetter.last7(list, t),
      welcomeBack: WeeklyLetter.isWelcomeBack(list, t),
      hasAny: list.isNotEmpty,
      todayCount: todayCount(),
    );
  }

  /// 今月の回数。
  int monthCount() => WeeklyLetter.monthCount(marks(), today());

  /// 最近 7 日の点灯（古い順、最後が今日）。
  List<bool> last7Days() => WeeklyLetter.last7(marks(), today());

  /// 今週の手紙の事実（1 回も手放していなければ null）。
  WeeklyStats? weeklyStats() {
    final list = marks();
    return list.isEmpty ? null : WeeklyLetter.stats(list, today());
  }

  /// 今日唱えた回数の合計（危機を除き、今日開始のセッションの count 合計。未完了も含む）。
  int todayCount() {
    final t = TimeRules.epochDay(today());
    var sum = 0;
    for (final s in allSessions()) {
      if (!s.crisis && TimeRules.epochDayOfMillis(s.startedAt) == t) sum += s.count;
    }
    return sum;
  }

  /// 今日まだ 1 回も手放していないか（「まだ 0 回の日」通知の判定）。
  bool isTodayEmpty() => todayCount() == 0;

  /// 日別の手放した回数（完了セッションの数）。キーはローカル日付 0 時の DateTime。[from]〜[to] の日付を含む。
  Map<DateTime, int> countsByDay(DateTime from, DateTime to) {
    final start = TimeRules.epochDay(from);
    final end = TimeRules.epochDay(to);
    final out = <DateTime, int>{};
    for (final m in marks()) {
      final d = m.epochDay;
      if (d < start || d > end) continue;
      final key = TimeRules.dateOfEpochDay(d);
      out[key] = (out[key] ?? 0) + 1;
    }
    return out;
  }

  /// よく手放した記憶（完了した実践のチップを多い順に、最大 [limit] 件）。
  List<({String tag, int count})> frequentTags({int limit = 8}) {
    final counts = <String, int>{};
    for (final m in marks()) {
      for (final t in m.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return _sortedByCountDesc(counts).take(limit).map((e) => (tag: e.key, count: e.value)).toList();
  }

  /// 代表チップ（memoryLabel）の出現回数の多い順（書く画面のチップ候補に使う）。
  List<({String label, int count})> topMemoryLabels(int n) {
    final counts = <String, int>{};
    for (final s in allSessions()) {
      final l = s.memoryLabel;
      if (l != null) counts[l] = (counts[l] ?? 0) + 1;
    }
    return _sortedByCountDesc(counts).take(n).map((e) => (label: e.key, count: e.value)).toList();
  }

  // ---- 待ち行列（あとで手放す） ----

  Future<String> addPendingEvent(int occurredAt, {String source = 'manual'}) async {
    final id = _newId();
    await _db.pending.put(id, PendingEvent(id: id, occurredAt: occurredAt, source: source).toMap());
    return id;
  }

  /// 未処理の「あとで手放す」（起きた時刻の新しい順）。
  List<PendingEvent> pendingEvents() {
    final list = _db.pending.values
        .map(PendingEvent.fromMap)
        .where((e) => e.isPending)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return list;
  }

  PendingEvent? pendingEventById(String id) {
    final raw = _db.pending.get(id);
    return raw == null ? null : PendingEvent.fromMap(raw);
  }

  Future<void> resolvePendingEvent(String id, String sessionId) async {
    final e = pendingEventById(id);
    if (e == null) return;
    await _db.pending.put(
      id,
      PendingEvent(id: e.id, occurredAt: e.occurredAt, source: e.source, resolvedSessionId: sessionId)
          .toMap(),
    );
  }

  Future<void> deletePendingEvent(String id) => _db.pending.delete(id);

  /// 実践データ（セッション・対話・あとで手放す）を消す。設定は残す。
  Future<void> deleteAll() async {
    await _db.sessions.clear();
    await _db.turns.clear();
    await _db.pending.clear();
  }

  /// 多い順（同数は先に出てきた順＝安定）。
  static List<MapEntry<String, int>> _sortedByCountDesc(Map<String, int> counts) {
    final entries = counts.entries.toList();
    final indexed = [for (var i = 0; i < entries.length; i++) (i: i, e: entries[i])];
    indexed.sort((a, b) {
      final c = b.e.value.compareTo(a.e.value);
      return c != 0 ? c : a.i.compareTo(b.i);
    });
    return indexed.map((x) => x.e).toList();
  }
}

