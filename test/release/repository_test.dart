import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:zero_app/features/release/data/content_repository.dart';
import 'package:zero_app/features/release/data/dialogue_repository.dart';
import 'package:zero_app/features/release/data/release_db.dart';
import 'package:zero_app/features/release/data/release_repository.dart';
import 'package:zero_app/features/release/data/release_settings_repository.dart';
import 'package:zero_app/features/release/domain/dialogue_engine.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/records.dart';
import 'package:zero_app/features/release/domain/release_settings.dart';

import 'release_test_helpers.dart';

/// 進められる時計。
class FakeClock {
  FakeClock(DateTime start) : millis = start.millisecondsSinceEpoch;
  int millis;
  int call() => millis;
  void set(DateTime t) => millis = t.millisecondsSinceEpoch;
}

void main() {
  late Directory tmp;
  final db = ReleaseDb();

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('release_db_test');
    Hive.init(tmp.path);
    await db.init();
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async => db.clearAll());

  group('ReleaseRepository', () {
    late FakeClock clock;
    late ReleaseRepository repo;
    var seq = 0;

    setUp(() {
      clock = FakeClock(DateTime(2026, 10, 18, 10)); // 日曜
      seq = 0;
      repo = ReleaseRepository(db, now: clock.call, newId: () => 'id${seq++}');
    });

    test('startSession stores an unfinished session with normalized note and tags', () async {
      final id = await repo.startSession(
        kind: SessionKind.WORDS4,
        note: '  hello  ',
        tags: [' 仕事 ', '', '仕事', '人'],
        scene: '  ',
        voiceRecordingId: 'rec1',
      );
      final s = repo.sessionById(id)!;
      expect(s.note, 'hello');
      expect(s.memoryTags, ['仕事', '人']);
      expect(s.memoryLabel, '仕事');
      expect(s.scene, isNull);
      expect(s.count, 0);
      expect(s.endedAt, isNull);
      expect(s.isCompleted, isFalse);
      expect(s.voiceRecordingId, 'rec1');
      expect(repo.records(), isEmpty);
    });

    test('blank note is not stored', () async {
      final id = await repo.startSession(kind: SessionKind.WORDS4, note: '   ');
      expect(repo.sessionById(id)!.note, isNull);
    });

    test('finishSession completes the session and counts it', () async {
      final id = await repo.startSession(kind: SessionKind.WORDS4, note: 'n', tags: ['仕事']);
      clock.set(DateTime(2026, 10, 18, 10, 5));
      await repo.finishSession(id, 27, moodAfter: 4);
      final s = repo.sessionById(id)!;
      expect(s.count, 27);
      expect(s.moodAfter, 4);
      expect(s.endedAt, clock.millis);
      expect(s.lastReleasedAt, clock.millis);
      expect(repo.monthCount(), 1);
      expect(repo.todayCount(), 27);
      expect(repo.isTodayEmpty(), isFalse);
      expect(repo.records().single.id, id);
      expect(repo.last7Days(), [false, false, false, false, false, false, true]);
      expect(repo.frequentTags(), [(tag: '仕事', count: 1)]);
      expect(repo.lastSessionAt(), clock.millis);
      expect(repo.completedTotal(), 1);
    });

    test('discardSession removes a 0-count session', () async {
      final id = await repo.startSession(kind: SessionKind.WORDS1);
      await repo.discardSession(id);
      expect(repo.sessionById(id), isNull);
      expect(repo.allSessions(), isEmpty);
    });

    test('release again bumps the source record and is not listed as a record itself', () async {
      final src = await repo.startSession(kind: SessionKind.WORDS4, note: 'boss', tags: ['仕事'], scene: '会う前');
      await repo.finishSession(src, 5);
      final draft = repo.releaseAgainDraft(src)!;
      expect(draft.note, 'boss');
      expect(draft.tags, ['仕事']);
      expect(draft.scene, '会う前');

      clock.set(DateTime(2026, 10, 18, 12));
      final again = await repo.startSession(
        kind: SessionKind.WORDS4,
        note: draft.note,
        tags: draft.tags,
        sourceSessionId: src,
      );
      await repo.finishSession(again, 3);
      final source = repo.sessionById(src)!;
      expect(source.releaseCount, 2);
      expect(source.lastReleasedAt, clock.millis);
      expect(repo.records().map((r) => r.id), [src]);
      expect(repo.monthCount(), 2);

      await repo.deleteRecord(src);
      expect(repo.sessionById(src), isNull);
      expect(repo.sessionById(again), isNull);
    });

    test('records are ordered by last released time', () async {
      final a = await repo.startSession(kind: SessionKind.WORDS4, note: 'a');
      await repo.finishSession(a, 1);
      clock.set(DateTime(2026, 10, 18, 11));
      final b = await repo.startSession(kind: SessionKind.WORDS4, note: 'b');
      await repo.finishSession(b, 1);
      expect(repo.records().map((r) => r.id), [b, a]);
      clock.set(DateTime(2026, 10, 18, 12));
      final again = await repo.startSession(kind: SessionKind.WORDS4, sourceSessionId: a);
      await repo.finishSession(again, 1);
      expect(repo.records().map((r) => r.id), [a, b]);
    });

    test('summary, weekly stats, countsByDay and welcome back', () async {
      Future<void> doneAt(DateTime t, [List<String> tags = const []]) async {
        clock.set(t);
        final id = await repo.startSession(kind: SessionKind.WORDS4, tags: tags);
        await repo.finishSession(id, 1);
      }

      await doneAt(DateTime(2026, 10, 13, 9), ['仕事']);
      await doneAt(DateTime(2026, 10, 13, 20), ['仕事']);
      await doneAt(DateTime(2026, 10, 18, 9), ['人']);
      clock.set(DateTime(2026, 10, 18, 22));
      final s = repo.summary();
      expect(s.monthCount, 3);
      expect(s.hasAny, isTrue);
      expect(s.welcomeBack, isTrue); // 13 日 → 18 日（5 日空き）
      expect(s.todayCount, 1);
      final w = repo.weeklyStats()!;
      expect(w.thisWeekCount, 3);
      expect(w.topTag, '仕事');
      final byDay = repo.countsByDay(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(byDay, {DateTime(2026, 10, 13): 2, DateTime(2026, 10, 18): 1});
      expect(repo.sessionsOnDay(DateTime(2026, 10, 13)).length, 2);
      expect(repo.topMemoryLabels(5).first, (label: '仕事', count: 2));
    });

    test('crisis sessions are not counted', () async {
      await db.sessions.put(
        'c',
        ReleaseSession(
          id: 'c',
          startedAt: clock.millis,
          endedAt: clock.millis,
          kind: SessionKind.CHAT_ONLY,
          count: 3,
          crisis: true,
        ).toMap(),
      );
      expect(repo.monthCount(), 0);
      expect(repo.todayCount(), 0);
      expect(repo.summary().hasAny, isFalse);
      expect(repo.weeklyStats(), isNull);
    });

    test('pending events: add, list newest first, resolve, delete', () async {
      final a = await repo.addPendingEvent(1000);
      final b = await repo.addPendingEvent(2000);
      expect(repo.pendingEvents().map((e) => e.id), [b, a]);
      await repo.resolvePendingEvent(a, 's1');
      expect(repo.pendingEvents().map((e) => e.id), [b]);
      expect(repo.pendingEventById(a)!.resolvedSessionId, 's1');
      await repo.deletePendingEvent(b);
      expect(repo.pendingEvents(), isEmpty);
    });

    test('watch emits on changes', () async {
      final events = <void>[];
      final sub = repo.watch().listen(events.add);
      await repo.addPendingEvent(1);
      await repo.startSession(kind: SessionKind.WORDS4);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(events.length, greaterThanOrEqualTo(2));
    });

    test('recordFilterTags counts tags and scenes', () {
      final r = [
        const ReleaseSession(id: 'a', startedAt: 0, kind: SessionKind.WORDS4, memoryTags: ['x', 'y'], scene: 's'),
        const ReleaseSession(id: 'b', startedAt: 0, kind: SessionKind.WORDS4, memoryTags: ['y']),
      ];
      expect(ReleaseRepository.recordFilterTags(r), ['y', 'x', 's']);
    });

    test('deleteAll keeps settings, clearAll removes everything', () async {
      final settings = ReleaseSettingsRepository(db);
      await settings.setGoalCount(108);
      await repo.startSession(kind: SessionKind.WORDS4);
      await repo.deleteAll();
      expect(repo.allSessions(), isEmpty);
      expect(settings.current.goalCount, 108);
      await db.clearAll();
      expect(settings.current.goalCount, 27);
    });
  });

  group('ReleaseSettingsRepository', () {
    test('defaults per design', () {
      final s = ReleaseSettingsRepository(db).current;
      expect(s.ttsEnabled, isFalse);
      expect(s.hapticsEnabled, isTrue);
      expect(s.goalCount, 27);
      expect(s.loopSpeed, 'normal');
      expect([s.breathIn, s.breathHold, s.breathOut], [4, 4, 8]);
      expect(s.quietStart, '22:00');
      expect(s.quietEnd, '07:00');
      expect(s.replayMode, ReplayMode.EVERY);
      expect(s.releaseTool, 'set');
      expect(s.keepNotes, isTrue);
      expect(s.disclaimerAcceptedAt, isNull);
      expect(s.lastCrisisAt, 0);
      expect(s.ownTools, isEmpty);
    });

    test('setters persist and normalize, watch emits', () async {
      final repo = ReleaseSettingsRepository(db);
      final emitted = <ReleaseSettings>[];
      final sub = repo.watch().listen(emitted.add);
      await repo.setCustomWords(['  Let go ', '', 'Thank you']);
      await repo.setOwnTools(['  Press the\nDelete key ', 'Press the Delete key']);
      await repo.setTriggerSentence('  ${'x' * 80}  ');
      await repo.setReplayMode(ReplayMode.OFF);
      await repo.setTriggerCues([TriggerCue.BEFORE_SLEEP, TriggerCue.BEFORE_SLEEP]);
      await repo.setDisclaimerAcceptedAt(123);
      await repo.pushRecentCardId('c1');
      await repo.pushRecentCardId('c2');
      await repo.pushRecentCardId('c1');
      await repo.setCheckinMorning(enabled: true);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      final s = ReleaseSettingsRepository(db).current; // 別インスタンスで読み直す
      expect(s.customWords, ['Let go', 'Thank you']);
      expect(s.ownTools, ['Press the Delete key']);
      expect(s.triggerSentence.length, 60);
      expect(s.replayMode, ReplayMode.OFF);
      expect(s.triggerCues, [TriggerCue.BEFORE_SLEEP]);
      expect(s.disclaimerAcceptedAt, 123);
      expect(s.recentCardIds, ['c2', 'c1']);
      expect(s.checkinMorningEnabled, isTrue);
      expect(s.checkinMorningTime, '07:30');
      expect(emitted.length, 10);

      await repo.setDisclaimerAcceptedAt(null);
      expect(repo.current.disclaimerAcceptedAt, isNull);
    });

    test('ReleaseSettings map round trip and copyWith', () {
      const s = ReleaseSettings(goalCount: 7, customWords: ['a'], triggerCues: [TriggerCue.ON_WAKING]);
      final back = ReleaseSettings.fromMap(s.toMap());
      expect(back.goalCount, 7);
      expect(back.customWords, ['a']);
      expect(back.triggerCues, [TriggerCue.ON_WAKING]);
      expect(ReleaseSettings.fromMap({'goalCount': 'bad'}).goalCount, 27);
      final c = s.copyWith(disclaimerAcceptedAt: 5);
      expect(c.disclaimerAcceptedAt, 5);
      expect(c.copyWith(goalCount: 1).disclaimerAcceptedAt, 5);
      expect(c.copyWith(disclaimerAcceptedAt: null).disclaimerAcceptedAt, isNull);
    });
  });

  group('DialogueRepository (production content via File loader)', () {
    late FakeClock clock;
    late ReleaseSettingsRepository settings;
    late DialogueRepository dialogue;

    setUp(() {
      clock = FakeClock(DateTime(2026, 10, 18, 14));
      settings = ReleaseSettingsRepository(db);
      var n = 0;
      dialogue = DialogueRepository(
        content: ContentRepository(const FileContentLoader()),
        db: db,
        settings: settings,
        random: Random(3),
        now: clock.call,
        newId: () => 'd${n++}',
      );
    });

    test('crisis: nothing of the text is stored, a crisis session and lastCrisisAt are recorded', () async {
      final r = await dialogue.respond(text: 'I want to die', lang: AppLang.en);
      expect(r.outcome, isA<DialogueCrisis>());
      expect(r.turnId, isNull);
      expect(db.turns.isEmpty, isTrue);
      final sessions = db.sessions.values.map(ReleaseSession.fromMap).toList();
      expect(sessions.single.crisis, isTrue);
      expect(sessions.single.note, isNull);
      expect(sessions.single.kind, SessionKind.CHAT_ONLY);
      expect(settings.current.lastCrisisAt, clock.millis);
    });

    test('stored turns are capped; the oldest are dropped first', () async {
      for (var i = 0; i < DialogueRepository.maxStoredTurns + 5; i++) {
        await db.turns.put('old$i', {
          'id': 'old$i',
          'at': i,
          'userText': 'old $i',
          'reflection': 'r',
          'trigger': 'UNKNOWN',
        });
      }
      final r = await dialogue.respond(text: '仕事に追われて焦ってしまう', lang: AppLang.ja);
      expect(r.outcome, isA<DialogueReply>());
      expect(db.turns.length, DialogueRepository.maxStoredTurns);
      expect(db.turns.containsKey('old0'), isFalse);
      expect(db.turns.containsKey('old5'), isFalse);
      expect(db.turns.containsKey('old6'), isTrue);
      expect(db.turns.containsKey(r.turnId), isTrue);
    });

    test('japanese crisis text is detected too', () async {
      final r = await dialogue.respond(text: 'もう死にたい', lang: AppLang.ja);
      expect(r.outcome, isA<DialogueCrisis>());
    });

    test('reply: a turn is stored and recent ids are pushed', () async {
      final r = await dialogue.respond(text: '仕事に追われて焦ってしまう', lang: AppLang.ja, sessionId: 's1');
      expect(r.outcome, isA<DialogueReply>());
      final turn = (r.outcome as DialogueReply).turn;
      expect(turn.reflection, isNotNull);
      expect(r.turnId, isNotNull);
      final saved = dialogue.turns(sessionId: 's1').single;
      expect(saved.userText, '仕事に追われて焦ってしまう');
      expect(saved.reflection, turn.reflection);
      expect(settings.current.recentReflectionIds, [turn.reflectionId]);
      if (turn.card != null) expect(settings.current.recentCardIds, [turn.card!.id]);
      expect(dialogue.recentTurns(5).length, 1);
    });

    test('long text is cut to 300 characters', () async {
      await dialogue.respond(text: 'a' * 500, lang: AppLang.en);
      expect(dialogue.turns().single.userText.length, 300);
    });

    test('free text is allowed only where a crisis dictionary exists', () async {
      expect(await dialogue.isFreeTextAllowed(AppLang.en), isTrue);
      expect(await dialogue.isFreeTextAllowed(AppLang.ja), isTrue);
      expect(await dialogue.isFreeTextAllowed(AppLang.es), isTrue);
      expect(await dialogue.isFreeTextAllowed(AppLang.pt), releaseAsset('pt', 'crisis.json').existsSync());
    });

    test('checkSafety and recordCrisis for the Write screen', () async {
      expect((await dialogue.checkSafety('I want to kill myself')).isCrisis, isTrue);
      expect((await dialogue.checkSafety('今日は少し疲れた')).level, SafetyLevel.OK);
      await dialogue.recordCrisis();
      expect(settings.current.lastCrisisAt, clock.millis);
      expect(db.sessions.length, 1);
    });

    test('anotherCard returns a card and remembers the previous one', () async {
      final c = await dialogue.anotherCard(previousCardId: 'r001', lang: AppLang.en);
      expect(c, isNotNull);
      expect(settings.current.recentCardIds, ['r001']);
    });
  });
}
