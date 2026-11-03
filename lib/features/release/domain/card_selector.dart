// 手放しカードを選ぶ。Luckarise の CardSelector.kt を移植。純 Dart。

import 'dart:math';

import 'content_models.dart';
import 'models.dart';

class CardSelector {
  CardSelector(this.cards, this.random);

  final Map<AppLang, List<CardItem>> cards;
  final Random random;

  /// 条件に合うカードを 1 枚。[kind] が NONE なら null。[kind] が null なら PRE 以外から。
  /// 優先: トリガー一致(100) > 感情一致(50) > ANY(10)、場面一致 +5。直近の id は避ける（全部直近なら許す）。
  CardItem? select({
    EmotionTag? emotion,
    TriggerKind? trigger,
    CardKind? kind,
    Scene? scene,
    Iterable<String> recentIds = const [],
    required AppLang locale,
  }) {
    if (kind == CardKind.NONE) return null;
    final all = _cardsFor(locale);
    if (all == null) return null;

    bool baseFilter(CardItem c) => kind != null ? c.kind == kind : c.kind != CardKind.PRE;

    bool matchesCondition(CardItem c) {
      final byTrigger = trigger != null && c.triggers.contains(trigger);
      if (emotion != null) {
        return c.emotions.contains(emotion.name) || c.emotions.contains('ANY') || byTrigger;
      }
      return c.emotions.contains('ANY') || byTrigger;
    }

    final withCondition = all.where((c) => baseFilter(c) && matchesCondition(c)).toList();
    final candidates = withCondition.isNotEmpty ? withCondition : all.where(baseFilter).toList();
    if (candidates.isEmpty) return null;

    int score(CardItem c) {
      var s = 0;
      if (trigger != null && c.triggers.contains(trigger)) {
        s += 100;
      } else if (emotion != null && c.emotions.contains(emotion.name)) {
        s += 50;
      } else if (c.emotions.contains('ANY')) {
        s += 10;
      }
      if (scene != null && c.scenes.contains(scene)) s += 5;
      return s;
    }

    final scored = [for (final c in candidates) (card: c, score: score(c))];
    final maxScore = scored.map((e) => e.score).reduce(max);
    final top = [for (final e in scored) if (e.score == maxScore) e.card];

    final recentSet = recentIds.toSet();
    final fresh = top.where((c) => !recentSet.contains(c.id)).toList();
    final pool = fresh.isNotEmpty ? fresh : top;
    return pool[random.nextInt(pool.length)];
  }

  List<CardItem> preCards(AppLang locale) =>
      (_cardsFor(locale) ?? const <CardItem>[]).where((c) => c.kind == CardKind.PRE).toList();

  CardItem? byId(String id, AppLang locale) {
    for (final c in _cardsFor(locale) ?? const <CardItem>[]) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<CardItem>? _cardsFor(AppLang locale) =>
      cards.containsKey(locale) ? cards[locale] : cards[AppLang.en];
}
