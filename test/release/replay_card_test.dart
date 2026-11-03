import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/card_selector.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/replay_reminder.dart';

import 'release_test_helpers.dart';

void main() {
  group('ReplayReminder (Kotlin ReplayReminderTest)', () {
    const items = [
      ReplayItem('u1', 'URGE', 'u1 text'),
      ReplayItem('u2', 'URGE', 'u2 text'),
      ReplayItem('u3', 'URGE', 'u3 text'),
      ReplayItem('o1', 'OTHER', 'o1 text'),
      ReplayItem('s1', 'SELF', 's1 text'),
      ReplayItem('r1', 'RESP', 'r1 text'),
      ReplayItem('f1', 'FILTER', 'f1 text'),
      ReplayItem('f2', 'FILTER', 'f2 text'),
      ReplayItem('f3', 'FILTER', 'f3 text'),
      ReplayItem('n1', 'NIGHT', 'n1 text'),
      ReplayItem('k1', 'UNKNOWN', 'unknown long text here'),
      ReplayItem('k2', 'UNKNOWN', 'short'),
    ];

    test('abuse context returns null for all triggers', () {
      final r = ReplayReminder({AppLang.en: items}, Random(1));
      for (final t in TriggerKind.values) {
        expect(r.pick(trigger: t, locale: AppLang.en, abuseContext: true), isNull);
      }
    });

    test('night picks from NIGHT category', () {
      final r = ReplayReminder({AppLang.en: items}, Random(1));
      expect(r.pick(trigger: TriggerKind.URGE, locale: AppLang.en, isNight: true)?.id, 'n1');
    });

    test('soft crisis picks shortest UNKNOWN', () {
      final r = ReplayReminder({AppLang.en: items}, Random(1));
      expect(r.pick(trigger: TriggerKind.URGE, locale: AppLang.en, softCrisis: true)?.id, 'k2');
    });

    test('does not repeat within last 7 ids when alternatives exist', () {
      final r = ReplayReminder({AppLang.en: items}, Random(42));
      final recent = <String>[];
      for (var i = 0; i < 100; i++) {
        final before = (recent.length <= 7 ? recent : recent.sublist(recent.length - 7)).toSet();
        final result = r.pick(trigger: TriggerKind.FILTER, locale: AppLang.en, recentIds: recent);
        if (result != null) {
          if (before.length < 3) expect(before.contains(result.id), isFalse);
          recent.add(result.id);
        }
      }
    });

    test('RESP substitution happens sometimes', () {
      final r = ReplayReminder({AppLang.en: items}, Random(7));
      var sawResp = false;
      final recent = <String>[];
      for (var i = 0; i < 500; i++) {
        final result = r.pick(trigger: TriggerKind.URGE, locale: AppLang.en, recentIds: recent);
        if (result?.id == 'r1') sawResp = true;
        if (result != null) recent.add(result.id);
      }
      expect(sawResp, isTrue);
    });

    test('daily picks from FILTER UNKNOWN RESP pool deterministically by day index', () {
      final r = ReplayReminder({AppLang.en: items}, Random(1));
      final d0 = r.daily(AppLang.en, 0)!;
      expect(r.daily(AppLang.en, 0)!.id, d0.id);
      expect({'FILTER', 'UNKNOWN', 'RESP'}.contains(d0.category), isTrue);
    });

    test('unknown language falls back to en', () {
      final r = ReplayReminder({AppLang.en: items}, Random(1));
      expect(r.pick(trigger: TriggerKind.URGE, locale: AppLang.pt, isNight: true)?.id, 'n1');
    });

    test('real replay json has expected counts per category', () {
      final replay = ReplayFile.parse(readUtf8(releaseAsset('en', 'replay.json')));
      final counts = <String, int>{};
      for (final i in replay.items) {
        counts[i.category] = (counts[i.category] ?? 0) + 1;
      }
      expect(counts['URGE'], 12);
      expect(counts['OTHER'], 12);
      expect(counts['SELF'], 12);
      expect(counts['UNKNOWN'], 3);
      expect(counts['NIGHT'], 2);
      expect(counts['FILTER'], 10);
      expect(counts['RESP'], 6);
    });
  });

  group('CardSelector (Kotlin CardSelectorTest)', () {
    CardItem card(
      String id, {
      CardKind kind = CardKind.WORDS4,
      List<String> emotions = const ['ANY'],
      List<TriggerKind> triggers = const [],
      List<Scene> scenes = const [],
    }) =>
        CardItem(
          id: id,
          kind: kind,
          emotions: emotions,
          triggers: triggers,
          scenes: scenes,
          text: 'text-$id',
          lang: 'en',
        );

    test('avoids recent ids when alternatives exist', () {
      final s = CardSelector({
        AppLang.en: [card('c1', emotions: ['ANXIETY']), card('c2', emotions: ['ANXIETY'])],
      }, Random(1));
      expect(
        s.select(emotion: EmotionTag.ANXIETY, kind: CardKind.WORDS4, recentIds: ['c1'], locale: AppLang.en)?.id,
        'c2',
      );
    });

    test('relaxes recent exclusion when all are recent', () {
      final s = CardSelector({
        AppLang.en: [card('c1', emotions: ['ANXIETY'])],
      }, Random(1));
      expect(
        s.select(emotion: EmotionTag.ANXIETY, kind: CardKind.WORDS4, recentIds: ['c1'], locale: AppLang.en)?.id,
        'c1',
      );
    });

    test('kind NONE returns null', () {
      final s = CardSelector({
        AppLang.en: [card('c1')],
      }, Random(1));
      expect(s.select(kind: CardKind.NONE, locale: AppLang.en), isNull);
    });

    test('kind null excludes PRE cards', () {
      final s = CardSelector({
        AppLang.en: [card('pre1', kind: CardKind.PRE), card('words1')],
      }, Random(1));
      expect(s.select(locale: AppLang.en)?.id, 'words1');
    });

    test('trigger match takes priority over emotion or any', () {
      final s = CardSelector({
        AppLang.en: [
          card('byAny'),
          card('byEmotion', emotions: ['ANXIETY']),
          card('byTrigger', triggers: [TriggerKind.URGE]),
        ],
      }, Random(1));
      expect(
        s
            .select(
              emotion: EmotionTag.ANXIETY,
              trigger: TriggerKind.URGE,
              kind: CardKind.WORDS4,
              locale: AppLang.en,
            )
            ?.id,
        'byTrigger',
      );
    });

    test('scene match is preferred among same priority tier', () {
      final s = CardSelector({
        AppLang.en: [
          card('noScene', emotions: ['ANXIETY']),
          card('withScene', emotions: ['ANXIETY'], scenes: [Scene.WORK]),
        ],
      }, Random(1));
      expect(
        s
            .select(emotion: EmotionTag.ANXIETY, kind: CardKind.WORDS4, scene: Scene.WORK, locale: AppLang.en)
            ?.id,
        'withScene',
      );
    });

    test('preCards returns only PRE kind', () {
      final s = CardSelector({
        AppLang.en: [card('pre1', kind: CardKind.PRE), card('words1')],
      }, Random(1));
      expect(s.preCards(AppLang.en).map((c) => c.id).toList(), ['pre1']);
    });

    test('byId finds card by id', () {
      final s = CardSelector({
        AppLang.en: [card('c1'), card('c2')],
      }, Random(1));
      expect(s.byId('c2', AppLang.en), isNotNull);
      expect(s.byId('missing', AppLang.en), isNull);
    });

    test('real cards json has 120 entries per language with matching ids', () {
      final en = CardsFile.parse(readUtf8(releaseAsset('en', 'cards.json')));
      final ja = CardsFile.parse(readUtf8(releaseAsset('ja', 'cards.json')));
      expect(en.cards.length, 120);
      expect(ja.cards.length, 120);
      expect(en.cards.map((c) => c.id).toSet(), ja.cards.map((c) => c.id).toSet());
      for (final c in ja.cards) {
        expect(c.text.length <= 60, isTrue, reason: 'ja card ${c.id} too long');
        expect(c.prompt?.startsWith('なぜ') ?? false, isFalse);
      }
      for (final c in en.cards) {
        expect(c.text.length <= 120, isTrue, reason: 'en card ${c.id} too long');
        expect(c.prompt?.toLowerCase().startsWith('why') ?? false, isFalse);
      }
    });
  });
}
