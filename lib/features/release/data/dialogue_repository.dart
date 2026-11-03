// 対話の 1 ターン（SafetyGate → DialogueEngine → OutputGate）。Luckarise の DialogueRepository.kt（RULE 経路）を移植。
// 危機と判定したら本文は保存せず、空の crisis セッションだけを残して lastCrisisAt を記録する。外部送信はしない。

import 'dart:math';

import '../domain/content_models.dart';
import '../domain/dialogue_engine.dart';
import '../domain/models.dart';
import '../domain/records.dart';
import '../domain/safety_gate.dart';
import 'content_repository.dart';
import 'release_db.dart';
import 'release_domain.dart';
import 'release_settings_repository.dart';

/// respond の結果と、保存したターンの id（危機のときは null）。
class RespondResult {
  const RespondResult(this.outcome, this.turnId);

  final DialogueOutcome outcome;
  final String? turnId;
}

class DialogueRepository {
  DialogueRepository({
    required ContentRepository content,
    required ReleaseDb db,
    required ReleaseSettingsRepository settings,
    Random? random,
    int Function()? now,
    String Function()? newId,
  })  : _content = content,
        _db = db,
        _settings = settings,
        _random = random,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _newId = newId ?? _defaultId;

  static const int maxUserTextLength = 300;

  /// 端末に残す対話のターン数の上限（古いものから消す）。
  static const int maxStoredTurns = 300;

  final ContentRepository _content;
  final ReleaseDb _db;
  final ReleaseSettingsRepository _settings;
  final Random? _random;
  final int Function() _now;
  final String Function() _newId;

  Future<ReleaseDomain>? _domain;

  static int _seq = 0;
  static String _defaultId() =>
      't${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}'
      '${Random().nextInt(1 << 30).toRadixString(36)}';

  /// ドメイン部品（初回だけ組み立てる）。
  Future<ReleaseDomain> domain() =>
      _domain ??= _content.bundle().then((b) => ReleaseDomain.build(b, random: _random));

  /// 入力の安全判定だけ（Write の自由入力にも使う）。
  Future<SafetyResult> checkSafety(String text) async =>
      (await domain()).safetyGate.checkInput(text);

  /// その言語で自由入力を出してよいか（危機辞書がある言語だけ。フォールバックしない）。
  Future<bool> isFreeTextAllowed(AppLang lang) async =>
      (await domain()).safetyGate.isFreeTextAllowed(lang);

  /// 危機の記録だけを残す（本文は保存しない）。Write の自由入力が CRISIS だったときにも呼ぶ。
  Future<void> recordCrisis() async {
    final now = _now();
    final id = _newId();
    await _db.sessions.put(
      id,
      ReleaseSession(
        id: id,
        startedAt: now,
        endedAt: now,
        kind: SessionKind.CHAT_ONLY,
        count: 0,
        crisis: true,
      ).toMap(),
    );
    await _settings.setLastCrisisAt(now);
  }

  /// 対話の 1 手。[text] は 300 文字で切る。感情チップから始めるときは text を空にして [emotionHint] を渡す。
  Future<RespondResult> respond({
    required String text,
    EmotionTag? emotionHint,
    required AppLang lang,
    String? sessionId,
    Scene? scene,
    bool replayShownInSession = false,
  }) async {
    final settings = _settings.current;
    final truncated = text.length > maxUserTextLength ? text.substring(0, maxUserTextLength) : text;
    final isNight = TimeRules.isNightHour(DateTime.fromMillisecondsSinceEpoch(_now()).hour);
    final input = DialogueInput(
      text: truncated,
      emotionHint: emotionHint,
      locale: lang,
      isNight: isNight,
      scene: scene,
      replayMode: settings.replayMode,
      replayShownInSession: replayShownInSession,
      recentReplayIds: settings.recentReplayIds,
      recentCardIds: settings.recentCardIds,
      recentReflectionIds: settings.recentReflectionIds,
    );
    final outcome = (await domain()).dialogueEngine.respond(input);

    switch (outcome) {
      case DialogueCrisis():
        await recordCrisis();
        return RespondResult(outcome, null);
      case DialogueReply(:final turn):
        final id = _newId();
        await _db.turns.put(
          id,
          ReleaseTurn(
            id: id,
            sessionId: sessionId,
            at: _now(),
            userText: truncated,
            reflection: turn.reflection ?? '',
            affirmation: turn.affirmation,
            faqText: turn.faqText,
            emotion: turn.emotion,
            trigger: turn.trigger,
            replayNoteId: turn.replay?.id,
            replayText: turn.replay?.text,
            cardId: turn.card?.id,
          ).toMap(),
        );
        await _pruneTurns();
        final reflectionId = turn.reflectionId;
        if (reflectionId != null) await _settings.pushRecentReflectionId(reflectionId);
        final replayId = turn.replay?.id;
        if (replayId != null) await _settings.pushRecentReplayId(replayId);
        final cardId = turn.card?.id;
        if (cardId != null) await _settings.pushRecentCardId(cardId);
        return RespondResult(outcome, id);
    }
  }

  /// 「別のカード」: 直前のカードを直近に積み、同じ感情・トリガーで選び直す（無ければ null）。
  Future<CardItem?> anotherCard({
    required String previousCardId,
    EmotionTag? emotion,
    TriggerKind? trigger,
    required AppLang lang,
  }) async {
    final s = await _settings.pushRecentCardId(previousCardId);
    final card = (await domain()).cardSelector.select(
          emotion: emotion,
          trigger: trigger,
          kind: null,
          scene: null,
          recentIds: s.recentCardIds,
          locale: lang,
        );
    if (card == null) return null;
    final gate = (await domain()).outputGate;
    final prompt = card.prompt;
    if (!gate.isClean(card.text) || (prompt != null && !gate.isClean(prompt))) return null;
    return card;
  }

  /// 保存したターン（古い順）。[sessionId] を渡すとそのセッションのものだけ。
  List<ReleaseTurn> turns({String? sessionId}) {
    final list = _db.turns.values
        .map(ReleaseTurn.fromMap)
        .where((t) => sessionId == null || t.sessionId == sessionId)
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return list;
  }

  /// 直近のターン（新しい順に最大 [limit] 件）。
  List<ReleaseTurn> recentTurns(int limit) {
    final all = turns();
    return all.reversed.take(limit).toList();
  }

  Future<void> clearTurns() => _db.turns.clear();

  /// [maxStoredTurns] を超えた古いターンを消す。
  Future<void> _pruneTurns() async {
    final box = _db.turns;
    final excess = box.length - maxStoredTurns;
    if (excess <= 0) return;
    final oldest = box.keys
        .map((k) => (key: k, at: (box.get(k)?['at'] as num?)?.toInt() ?? 0))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    await box.deleteAll(oldest.take(excess).map((e) => e.key));
  }
}
