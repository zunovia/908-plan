// 再生リマインド（短い一文）を選ぶ。Luckarise の ReplayReminder.kt を移植。純 Dart。

import 'dart:math';

import 'content_models.dart';
import 'models.dart';

class ReplayReminder {
  ReplayReminder(this.templates, this.random);

  final Map<AppLang, List<ReplayItem>> templates;
  final Random random;

  /// 虐待・ハラスメントの文脈では null。柔らかい危機は UNKNOWN の最短文。夜は NIGHT。
  /// URGE/OTHER/SELF は 10% の確率で RESP（100% の責任）に置き換える。直近 7 件は避ける。
  ReplayItem? pick({
    required TriggerKind trigger,
    EmotionTag? emotion,
    required AppLang locale,
    List<String> recentIds = const [],
    bool isNight = false,
    bool abuseContext = false,
    bool softCrisis = false,
  }) {
    if (abuseContext) return null;
    final items = _itemsFor(locale);
    if (items == null) return null;

    if (softCrisis) {
      ReplayItem? shortest;
      for (final i in items) {
        if (i.category != 'UNKNOWN') continue;
        if (shortest == null || i.text.length < shortest.text.length) shortest = i;
      }
      return shortest;
    }

    if (isNight) return _pickFromCategory(items, 'NIGHT', recentIds);

    var effective = trigger;
    if ((trigger == TriggerKind.URGE || trigger == TriggerKind.OTHER || trigger == TriggerKind.SELF) &&
        random.nextDouble() < 0.1) {
      effective = TriggerKind.RESP;
    }
    return _pickFromCategory(items, effective.name, recentIds);
  }

  /// 日替わりの一文（FILTER / UNKNOWN / RESP を id 順に並べ、[dayIndex] で回す）。無ければ null。
  ReplayItem? daily(AppLang locale, int dayIndex) {
    final pool = (_itemsFor(locale) ?? const <ReplayItem>[])
        .where((i) => i.category == 'FILTER' || i.category == 'UNKNOWN' || i.category == 'RESP')
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (pool.isEmpty) return null;
    return pool[dayIndex % pool.length];
  }

  /// id から一文を引く（[locale] に無ければ en）。
  ReplayItem? byId(String id, AppLang locale) {
    for (final i in _itemsFor(locale) ?? const <ReplayItem>[]) {
      if (i.id == id) return i;
    }
    return null;
  }

  List<ReplayItem>? _itemsFor(AppLang locale) =>
      templates.containsKey(locale) ? templates[locale] : templates[AppLang.en];

  ReplayItem? _pickFromCategory(List<ReplayItem> items, String category, List<String> recentIds) {
    final candidates = items.where((i) => i.category == category).toList();
    if (candidates.isEmpty) return null;
    final window = recentIds.length <= 7 ? recentIds : recentIds.sublist(recentIds.length - 7);
    final recentSet = window.toSet();
    final fresh = candidates.where((i) => !recentSet.contains(i.id)).toList();
    if (fresh.isNotEmpty) return fresh[random.nextInt(fresh.length)];
    for (final id in window) {
      for (final c in candidates) {
        if (c.id == id) return c;
      }
    }
    return candidates[random.nextInt(candidates.length)];
  }
}
