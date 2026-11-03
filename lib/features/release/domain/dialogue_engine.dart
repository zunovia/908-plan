// 対話の一手を組み立てる（RULE 経路のみ）。Luckarise の DialogueEngine.kt（respond）を移植。純 Dart。
// 安全判定 → 規則解析 → 反映/再生/肯定/カード → 出力ゲート、の順。AI 経路（composeWithRemote）は持たない。

import 'dart:math';

import 'card_selector.dart';
import 'content_models.dart';
import 'models.dart';
import 'output_gate.dart';
import 'replay_reminder.dart';
import 'rule_route.dart';
import 'safety_gate.dart';

/// その言語の反映・肯定・FAQ 文面。
class DialogueTexts {
  const DialogueTexts({
    this.reflections = const [],
    this.affirmations = const [],
    this.faqs = const [],
  });

  final List<Reflection> reflections;
  final List<Affirmation> affirmations;
  final List<FaqItem> faqs;
}

class DialogueInput {
  const DialogueInput({
    required this.text,
    this.emotionHint,
    required this.locale,
    this.isNight = false,
    this.scene,
    this.replayMode = ReplayMode.EVERY,
    this.replayShownInSession = false,
    this.recentReplayIds = const [],
    this.recentCardIds = const [],
    this.recentReflectionIds = const [],
  });

  final String text;
  final EmotionTag? emotionHint;
  final AppLang locale;
  final bool isNight;
  final Scene? scene;
  final ReplayMode replayMode;
  final bool replayShownInSession;
  final List<String> recentReplayIds;
  final List<String> recentCardIds;
  final List<String> recentReflectionIds;
}

class TurnResult {
  const TurnResult({
    this.reflectionId,
    this.reflection,
    this.affirmationId,
    this.affirmation,
    this.faqText,
    this.emotion,
    required this.trigger,
    this.replay,
    this.card,
    this.route = RouteId.RULE,
    required this.softCrisis,
    required this.abuseContext,
  });

  final String? reflectionId;
  final String? reflection;
  final String? affirmationId;
  final String? affirmation;

  /// FAQ に一致したときの答え（このときは肯定文を出さない）。
  final String? faqText;
  final EmotionTag? emotion;
  final TriggerKind trigger;
  final ReplayItem? replay;
  final CardItem? card;
  final RouteId route;

  /// 柔らかい危機（窓口バナーを出して続行）。
  final bool softCrisis;

  /// 虐待・ハラスメントの文脈（再生リマインドとカードは出さない）。
  final bool abuseContext;
}

/// respond の結果。[DialogueCrisis] か [DialogueReply]。
sealed class DialogueOutcome {
  const DialogueOutcome();
}

class DialogueCrisis extends DialogueOutcome {
  const DialogueCrisis({required this.abuse});

  /// 虐待の文脈（相談窓口で ABUSE の行を先頭に）。
  final bool abuse;
}

class DialogueReply extends DialogueOutcome {
  const DialogueReply(this.turn);
  final TurnResult turn;
}

class DialogueEngine {
  DialogueEngine({
    required this.safety,
    required this.outputGate,
    required this.rule,
    required this.replay,
    required this.cards,
    required this.texts,
    required this.random,
  });

  final SafetyGate safety;
  final OutputGate outputGate;
  final RuleRoute rule;
  final ReplayReminder replay;
  final CardSelector cards;
  final Map<AppLang, DialogueTexts> texts;
  final Random random;

  /// 入力の安全判定だけを行う。
  SafetyResult checkSafety(String text) => safety.checkInput(text);

  DialogueOutcome respond(DialogueInput input) {
    final safetyResult = safety.checkInput(input.text);
    if (safetyResult.level == SafetyLevel.CRISIS) {
      return DialogueCrisis(abuse: safetyResult.abuseContext);
    }
    final softCrisis = safetyResult.level == SafetyLevel.CRISIS_SOFT;
    final abuseContext = safetyResult.abuseContext;

    final analysis = rule.analyze(input.text, input.locale, input.emotionHint);
    final dt = texts[input.locale] ?? texts[AppLang.en] ?? const DialogueTexts();

    // 反映文
    String? reflectionId;
    String? reflectionText;
    {
      final emotionKey = analysis.emotion?.name ?? 'GENERIC';
      var pool = dt.reflections.where((r) => r.emotion == emotionKey).toList();
      if (pool.isEmpty && emotionKey != 'GENERIC') {
        pool = dt.reflections.where((r) => r.emotion == 'GENERIC').toList();
      }
      final hasWord = analysis.quoteWord != null;
      final byWordNeed = hasWord ? pool : pool.where((r) => !r.needsWord).toList();
      final candidatePool = byWordNeed.isNotEmpty ? byWordNeed : pool;
      final recentSet = input.recentReflectionIds.toSet();
      final fresh = candidatePool.where((r) => !recentSet.contains(r.id)).toList();
      final finalPool = fresh.isNotEmpty ? fresh : candidatePool;
      if (finalPool.isNotEmpty) {
        final chosen = finalPool[random.nextInt(finalPool.length)];
        reflectionId = chosen.id;
        final quote = analysis.quoteWord;
        reflectionText =
            (chosen.needsWord && quote != null) ? chosen.text.replaceAll('{w}', quote) : chosen.text;
      }
    }

    // 再生リマインド
    ReplayItem? replayItem;
    if (input.replayMode != ReplayMode.OFF) {
      final skip = input.replayMode == ReplayMode.ONCE_PER_SESSION && input.replayShownInSession;
      if (!skip) {
        replayItem = replay.pick(
          trigger: analysis.trigger,
          emotion: analysis.emotion,
          locale: input.locale,
          recentIds: input.recentReplayIds,
          isNight: input.isNight,
          abuseContext: abuseContext,
          softCrisis: softCrisis,
        );
      }
    }

    // FAQ か肯定文
    String? affirmationId;
    String? affirmationText;
    String? faqText;
    if (analysis.faqId != null) {
      for (final f in dt.faqs) {
        if (f.id == analysis.faqId) {
          faqText = f.text;
          break;
        }
      }
    } else {
      final nightPool = dt.affirmations.where((a) => a.night == input.isNight).toList();
      final chosenPool = nightPool.isNotEmpty ? nightPool : dt.affirmations;
      if (chosenPool.isNotEmpty) {
        final chosen = chosenPool[random.nextInt(chosenPool.length)];
        affirmationId = chosen.id;
        affirmationText = chosen.text;
      }
    }

    // カード
    CardItem? card;
    if (!abuseContext) {
      card = cards.select(
        emotion: analysis.emotion,
        trigger: analysis.trigger,
        kind: null,
        scene: input.scene,
        recentIds: input.recentCardIds,
        locale: input.locale,
      );
    }

    // 出力ゲート
    if (reflectionText != null && !outputGate.isClean(reflectionText)) {
      Reflection? fallback;
      for (final r in dt.reflections) {
        if (r.emotion == 'GENERIC' && !r.needsWord) {
          fallback = r;
          break;
        }
      }
      reflectionId = fallback?.id;
      reflectionText = fallback?.text;
    }
    if (affirmationText != null && !outputGate.isClean(affirmationText)) {
      final fallback = dt.affirmations.isEmpty ? null : dt.affirmations.first;
      affirmationId = fallback?.id;
      affirmationText = fallback?.text;
    }
    if (faqText != null && !outputGate.isClean(faqText)) faqText = null;
    if (card != null) {
      final prompt = card.prompt;
      final promptClean = prompt == null || outputGate.isClean(prompt);
      if (!outputGate.isClean(card.text) || !promptClean) card = null;
    }

    return DialogueReply(
      TurnResult(
        reflectionId: reflectionId,
        reflection: reflectionText,
        affirmationId: affirmationId,
        affirmation: affirmationText,
        faqText: faqText,
        emotion: analysis.emotion,
        trigger: analysis.trigger,
        replay: replayItem,
        card: card,
        softCrisis: softCrisis,
        abuseContext: abuseContext,
      ),
    );
  }
}
