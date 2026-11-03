import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/card_selector.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/dialogue_engine.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/output_gate.dart';
import 'package:zero_app/features/release/domain/replay_reminder.dart';
import 'package:zero_app/features/release/domain/rule_route.dart';
import 'package:zero_app/features/release/domain/safety_gate.dart';

DialogueEngine buildEngine({OutputGate gate = const OutputGate.empty(), Random? random}) {
  final rnd = random ?? Random(1);
  const safety = SafetyGate({
    AppLang.en: CrisisLexicon(
      direct: ['want to die'],
      abuse: ['he hits me'],
      harassment: ['stalking me'],
      soft: ['hopeless'],
    ),
  });
  const rule = RuleRoute({
    AppLang.en: Lexicon(entries: [
      LexiconEntry(emotion: 'ANXIETY', terms: ['worried'], quote: 'okay', weight: 2),
    ]),
  }, {}, {});
  final replay = ReplayReminder({
    AppLang.en: const [
      ReplayItem('u1', 'URGE', 'replay urge'),
      ReplayItem('o1', 'OTHER', 'replay other'),
      ReplayItem('s1', 'SELF', 'replay self'),
      ReplayItem('n1', 'NIGHT', 'replay night'),
      ReplayItem('k1', 'UNKNOWN', 'replay unknown'),
    ],
  }, rnd);
  final cards = CardSelector({
    AppLang.en: const [CardItem(id: 'c1', kind: CardKind.WORDS4, emotions: ['ANY'], text: 'card text', lang: 'en')],
  }, rnd);
  const texts = {
    AppLang.en: DialogueTexts(
      reflections: [
        Reflection('r1', 'GENERIC', 'generic reflection'),
        Reflection('r2', 'ANXIETY', 'anxious reflection {w}', needsWord: true),
      ],
      affirmations: [
        Affirmation('a1', 'day affirmation'),
        Affirmation('a2', 'night affirmation', night: true),
      ],
      faqs: [
        FaqItem('f1', ['not working'], 'faq answer'),
      ],
    ),
  };
  return DialogueEngine(
    safety: safety,
    outputGate: gate,
    rule: RuleRoute(rule.lexicons, rule.triggerLex, {
      AppLang.en: texts[AppLang.en]!.faqs,
    }),
    replay: replay,
    cards: cards,
    texts: texts,
    random: rnd,
  );
}

DialogueInput input(
  String text, {
  EmotionTag? emotionHint,
  bool isNight = false,
  ReplayMode replayMode = ReplayMode.EVERY,
  bool replayShownInSession = false,
}) =>
    DialogueInput(
      text: text,
      emotionHint: emotionHint,
      locale: AppLang.en,
      isNight: isNight,
      scene: Scene.ANY,
      replayMode: replayMode,
      replayShownInSession: replayShownInSession,
    );

TurnResult turnOf(DialogueOutcome o) => (o as DialogueReply).turn;

void main() {
  group('DialogueEngine RULE (Kotlin DialogueEngineTest)', () {
    test('crisis text returns Crisis outcome', () {
      final o = buildEngine().respond(input('I want to die tonight'));
      expect(o, isA<DialogueCrisis>());
      expect((o as DialogueCrisis).abuse, isFalse);
    });

    test('abuse text returns Crisis with abuse true', () {
      final o = buildEngine().respond(input('he hits me every day'));
      expect(o, isA<DialogueCrisis>());
      expect((o as DialogueCrisis).abuse, isTrue);
    });

    test('normal input returns reply with reflection replay and card', () {
      final t = turnOf(buildEngine().respond(input('I am worried about this')));
      expect(t.reflection, isNotNull);
      expect(t.replay, isNotNull);
      expect(t.card, isNotNull);
      expect(t.route, RouteId.RULE);
      expect(t.emotion, EmotionTag.ANXIETY);
    });

    test('quote word is inserted into needsWord reflections', () {
      final t = turnOf(buildEngine().respond(input('I am worried')));
      expect(t.reflection, 'anxious reflection okay');
    });

    test('replay OFF mode suppresses replay', () {
      expect(turnOf(buildEngine().respond(input('I am worried', replayMode: ReplayMode.OFF))).replay, isNull);
    });

    test('ONCE_PER_SESSION suppresses replay on second call', () {
      final t = turnOf(buildEngine().respond(
        input('I am worried', replayMode: ReplayMode.ONCE_PER_SESSION, replayShownInSession: true),
      ));
      expect(t.replay, isNull);
    });

    test('night input uses night affirmation', () {
      final t = turnOf(buildEngine().respond(input('I am worried', isNight: true)));
      expect(t.affirmationId, 'a2');
      expect(t.affirmation, 'night affirmation');
      expect(t.replay?.id, 'n1');
    });

    test('empty text with hint still produces a reflection', () {
      final t = turnOf(buildEngine().respond(input('', emotionHint: EmotionTag.ANXIETY)));
      expect(t.reflection, isNotNull);
    });

    test('abuse context suppresses replay and card', () {
      final t = turnOf(buildEngine().respond(input('someone is stalking me online')));
      expect(t.abuseContext, isTrue);
      expect(t.replay, isNull);
      expect(t.card, isNull);
    });

    test('soft crisis is flagged and continues', () {
      final t = turnOf(buildEngine().respond(input('everything feels hopeless')));
      expect(t.softCrisis, isTrue);
      expect(t.replay?.id, 'k1');
    });

    test('faq match replaces the affirmation', () {
      final t = turnOf(buildEngine().respond(input('this is not working')));
      expect(t.faqText, 'faq answer');
      expect(t.affirmation, isNull);
    });

    test('output gate replaces a flagged reflection with the generic one and drops the card', () {
      final gate = OutputGate({OutputGate.sha256Hex('anxious'), OutputGate.sha256Hex('card')}, const {});
      final t = turnOf(buildEngine(gate: gate).respond(input('I am worried')));
      expect(t.reflection, 'generic reflection');
      expect(t.reflectionId, 'r1');
      expect(t.card, isNull);
    });

    test('average response time is within 50ms', () {
      final engine = buildEngine();
      final sw = Stopwatch()..start();
      for (var i = 0; i < 200; i++) {
        engine.respond(input('I am worried about this and that'));
      }
      expect(sw.elapsedMilliseconds / 200, lessThan(50));
    });
  });
}
