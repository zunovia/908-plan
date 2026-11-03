// コンテンツの束から RULE 経路のドメイン部品を一度だけ組み立てて持つ。
// Luckarise の data/repo/DomainProvider.kt に対応。

import 'dart:math';

import '../domain/card_selector.dart';
import '../domain/dialogue_engine.dart';
import '../domain/models.dart';
import '../domain/output_gate.dart';
import '../domain/replay_reminder.dart';
import '../domain/rule_route.dart';
import '../domain/safety_gate.dart';
import 'content_repository.dart';

class ReleaseDomain {
  ReleaseDomain._({
    required this.content,
    required this.safetyGate,
    required this.outputGate,
    required this.ruleRoute,
    required this.replayReminder,
    required this.cardSelector,
    required this.dialogueEngine,
  });

  factory ReleaseDomain.build(LoadedContent content, {Random? random}) {
    final rnd = random ?? Random();
    final safety = SafetyGate(content.crisis);
    final gateData = content.outputGate;
    final output = gateData == null ? const OutputGate.empty() : OutputGate.from(gateData);
    final rule = RuleRoute(content.lexicons, content.triggers, content.faqs);
    final replay = ReplayReminder(content.replay, rnd);
    final cards = CardSelector(content.cards, rnd);
    final texts = {
      for (final lang in AppLang.values)
        lang: DialogueTexts(
          reflections: content.reflections[lang] ?? content.reflections[AppLang.en] ?? const [],
          affirmations: content.affirmations[lang] ?? content.affirmations[AppLang.en] ?? const [],
          faqs: content.faqs[lang] ?? content.faqs[AppLang.en] ?? const [],
        ),
    };
    return ReleaseDomain._(
      content: content,
      safetyGate: safety,
      outputGate: output,
      ruleRoute: rule,
      replayReminder: replay,
      cardSelector: cards,
      dialogueEngine: DialogueEngine(
        safety: safety,
        outputGate: output,
        rule: rule,
        replay: replay,
        cards: cards,
        texts: texts,
        random: rnd,
      ),
    );
  }

  final LoadedContent content;
  final SafetyGate safetyGate;
  final OutputGate outputGate;
  final RuleRoute ruleRoute;
  final ReplayReminder replayReminder;
  final CardSelector cardSelector;
  final DialogueEngine dialogueEngine;
}
