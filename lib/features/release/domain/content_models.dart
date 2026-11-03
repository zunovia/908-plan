// assets/release/<lang>/*.json と common/*.json のモデル。Luckarise の domain/content を移植。
// 未知キーは無視し、必須の値（id・text など）が欠けた項目は捨てる（ファイル全体は壊さない）。
// 純 Dart。
import 'dart:convert';

import 'models.dart';

// ---- 読み取りの小道具 ----

Map<String, dynamic> _asMap(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

String? _strOrNull(Map<String, dynamic> m, String key) {
  final v = m[key];
  return v is String ? v : null;
}

String _str(Map<String, dynamic> m, String key, [String def = '']) =>
    _strOrNull(m, key) ?? def;

int _int(Map<String, dynamic> m, String key, int def) {
  final v = m[key];
  return v is num ? v.toInt() : def;
}

int? _intOrNull(Map<String, dynamic> m, String key) {
  final v = m[key];
  return v is num ? v.toInt() : null;
}

bool _bool(Map<String, dynamic> m, String key, bool def) {
  final v = m[key];
  return v is bool ? v : def;
}

List<String> _strList(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is! List) return const [];
  return v.whereType<String>().toList();
}

List<T> _objList<T>(
  Map<String, dynamic> m,
  String key,
  T? Function(Map<String, dynamic>) parse,
) {
  final v = m[key];
  if (v is! List) return const [];
  final out = <T>[];
  for (final e in v) {
    if (e is Map) {
      final parsed = parse(_asMap(e));
      if (parsed != null) out.add(parsed);
    }
  }
  return out;
}

Map<String, dynamic> _decode(String json) => _asMap(jsonDecode(json));

/// id と text を持つだけの項目の共通部分。
abstract class TextItem {
  String get id;
  String get text;
}

// ---- words.json ----

class WordItem implements TextItem {
  const WordItem(this.id, this.text);

  @override
  final String id;
  @override
  final String text;

  static WordItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return WordItem(id, text);
  }
}

class WordsFile {
  const WordsFile({this.version = 1, this.four = const [], this.items = const []});

  final int version;

  /// 「いつもの手放す言葉の組」の id（並び順どおり）。
  final List<String> four;
  final List<WordItem> items;

  factory WordsFile.fromJson(Map<String, dynamic> m) => WordsFile(
        version: _int(m, 'version', 1),
        four: _strList(m, 'four'),
        items: _objList(m, 'items', WordItem.fromJson),
      );

  static WordsFile parse(String json) => WordsFile.fromJson(_decode(json));

  /// id 一覧を表示文に（見つからない id はそのまま）。
  List<String> idsToText(List<String> ids) {
    final map = {for (final i in items) i.id: i.text};
    return ids.map((id) => map[id] ?? id).toList();
  }

  /// 単一 id の表示文（見つからなければ null）。
  String? textFor(String id) {
    for (final i in items) {
      if (i.id == id) return i.text;
    }
    return null;
  }
}

// ---- 単純な {id, text, night?} 系 ----

class ChildItem implements TextItem {
  const ChildItem(this.id, this.text, {this.night = false});
  @override
  final String id;
  @override
  final String text;
  final bool night;

  static ChildItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return ChildItem(id, text, night: _bool(m, 'night', false));
  }
}

class ChildFile {
  const ChildFile({this.version = 1, this.items = const []});
  final int version;
  final List<ChildItem> items;

  factory ChildFile.fromJson(Map<String, dynamic> m) => ChildFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', ChildItem.fromJson),
      );
  static ChildFile parse(String json) => ChildFile.fromJson(_decode(json));
}

class SurrenderItem implements TextItem {
  const SurrenderItem(this.id, this.text, {this.night = false});
  @override
  final String id;
  @override
  final String text;
  final bool night;

  static SurrenderItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return SurrenderItem(id, text, night: _bool(m, 'night', false));
  }
}

class SurrenderFile {
  const SurrenderFile({this.version = 1, this.items = const []});
  final int version;
  final List<SurrenderItem> items;

  factory SurrenderFile.fromJson(Map<String, dynamic> m) => SurrenderFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', SurrenderItem.fromJson),
      );
  static SurrenderFile parse(String json) => SurrenderFile.fromJson(_decode(json));
}

class Affirmation implements TextItem {
  const Affirmation(this.id, this.text, {this.night = false});
  @override
  final String id;
  @override
  final String text;
  final bool night;

  static Affirmation? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return Affirmation(id, text, night: _bool(m, 'night', false));
  }
}

class AffirmationsFile {
  const AffirmationsFile({this.version = 1, this.items = const []});
  final int version;
  final List<Affirmation> items;

  factory AffirmationsFile.fromJson(Map<String, dynamic> m) => AffirmationsFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', Affirmation.fromJson),
      );
  static AffirmationsFile parse(String json) =>
      AffirmationsFile.fromJson(_decode(json));
}

class NoteItem implements TextItem {
  const NoteItem(this.id, this.text);
  @override
  final String id;
  @override
  final String text;

  static NoteItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return NoteItem(id, text);
  }
}

class NotesFile {
  const NotesFile({this.version = 1, this.items = const []});
  final int version;
  final List<NoteItem> items;

  factory NotesFile.fromJson(Map<String, dynamic> m) => NotesFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', NoteItem.fromJson),
      );
  static NotesFile parse(String json) => NotesFile.fromJson(_decode(json));
}

class TodayItem implements TextItem {
  const TodayItem(this.id, this.text);
  @override
  final String id;
  @override
  final String text;

  static TodayItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return TodayItem(id, text);
  }
}

class TodayFile {
  const TodayFile({this.version = 1, this.items = const []});
  final int version;
  final List<TodayItem> items;

  factory TodayFile.fromJson(Map<String, dynamic> m) => TodayFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', TodayItem.fromJson),
      );
  static TodayFile parse(String json) => TodayFile.fromJson(_decode(json));
}

/// 通知文。[slot] は MORNING / NOON / NIGHT / BELL。
class NotificationItem implements TextItem {
  const NotificationItem(this.id, this.slot, this.text);
  @override
  final String id;
  final String slot;
  @override
  final String text;

  static NotificationItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return NotificationItem(id, _str(m, 'slot'), text);
  }
}

class NotificationsFile {
  const NotificationsFile({this.version = 1, this.items = const []});
  final int version;
  final List<NotificationItem> items;

  factory NotificationsFile.fromJson(Map<String, dynamic> m) => NotificationsFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', NotificationItem.fromJson),
      );
  static NotificationsFile parse(String json) =>
      NotificationsFile.fromJson(_decode(json));
}

class QuoteItem implements TextItem {
  const QuoteItem(this.id, this.text, this.source);
  @override
  final String id;
  @override
  final String text;
  final String source;

  static QuoteItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return QuoteItem(id, text, _str(m, 'source'));
  }
}

class QuotesFile {
  const QuotesFile({this.version = 1, this.items = const []});
  final int version;
  final List<QuoteItem> items;

  factory QuotesFile.fromJson(Map<String, dynamic> m) => QuotesFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', QuoteItem.fromJson),
      );
  static QuotesFile parse(String json) => QuotesFile.fromJson(_decode(json));
}

// ---- replay.json ----

/// 再生リマインドの 1 文。[category] は URGE/OTHER/SELF/RESP/FILTER/UNKNOWN/NIGHT。
class ReplayItem implements TextItem {
  const ReplayItem(this.id, this.category, this.text, {this.slot});
  @override
  final String id;
  final String category;
  @override
  final String text;
  final String? slot;

  static ReplayItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return ReplayItem(id, _str(m, 'category'), text, slot: _strOrNull(m, 'slot'));
  }
}

class ReplayFile {
  const ReplayFile({this.version = 1, this.items = const []});
  final int version;
  final List<ReplayItem> items;

  factory ReplayFile.fromJson(Map<String, dynamic> m) => ReplayFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', ReplayItem.fromJson),
      );
  static ReplayFile parse(String json) => ReplayFile.fromJson(_decode(json));
}

// ---- cards.json ----

/// 手放しカード。[emotions] は EmotionTag の名前か "ANY"。
class CardItem {
  const CardItem({
    required this.id,
    required this.kind,
    this.emotions = const [],
    this.triggers = const [],
    this.scenes = const [],
    required this.text,
    this.prompt,
    this.repeat,
    this.words = const [],
    this.breath,
    this.preScene,
    this.lang = '',
    this.ver = 1,
  });

  final String id;
  final CardKind kind;
  final List<String> emotions;
  final List<TriggerKind> triggers;
  final List<Scene> scenes;
  final String text;
  final String? prompt;
  final int? repeat;

  /// words.json の id（PRE カードで唱える言葉）。
  final List<String> words;
  final List<int>? breath;
  final String? preScene;
  final String lang;
  final int ver;

  bool matchesEmotion(String? emotionName) {
    if (emotionName == null) return emotions.contains('ANY');
    return emotions.contains('ANY') || emotions.contains(emotionName);
  }

  /// kind が不明・id/text が無いカードは null（捨てる）。
  static CardItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    final kind = enumByName(CardKind.values, _strOrNull(m, 'kind'));
    if (id == null || text == null || kind == null) return null;
    final breathRaw = m['breath'];
    return CardItem(
      id: id,
      kind: kind,
      emotions: _strList(m, 'emotions'),
      triggers: _strList(m, 'triggers')
          .map((t) => enumByName(TriggerKind.values, t))
          .whereType<TriggerKind>()
          .toList(),
      scenes: _strList(m, 'scenes')
          .map((s) => enumByName(Scene.values, s))
          .whereType<Scene>()
          .toList(),
      text: text,
      prompt: _strOrNull(m, 'prompt'),
      repeat: _intOrNull(m, 'repeat'),
      words: _strList(m, 'words'),
      breath: breathRaw is List
          ? breathRaw.whereType<num>().map((n) => n.toInt()).toList()
          : null,
      preScene: _strOrNull(m, 'preScene'),
      lang: _str(m, 'lang'),
      ver: _int(m, 'ver', 1),
    );
  }
}

class CardsFile {
  const CardsFile({this.version = 1, this.cards = const []});
  final int version;
  final List<CardItem> cards;

  factory CardsFile.fromJson(Map<String, dynamic> m) => CardsFile(
        version: _int(m, 'version', 1),
        cards: _objList(m, 'cards', CardItem.fromJson),
      );
  static CardsFile parse(String json) => CardsFile.fromJson(_decode(json));
}

// ---- reflections.json ----

/// 反映テンプレ。[emotion] は EmotionTag の名前か "GENERIC"。[needsWord] なら {w} に引用語を差し込む。
class Reflection implements TextItem {
  const Reflection(this.id, this.emotion, this.text, {this.needsWord = false});
  @override
  final String id;
  final String emotion;
  @override
  final String text;
  final bool needsWord;

  static Reflection? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return Reflection(id, _str(m, 'emotion', 'GENERIC'), text,
        needsWord: _bool(m, 'needsWord', false));
  }
}

class ReflectionsFile {
  const ReflectionsFile({this.version = 1, this.items = const []});
  final int version;
  final List<Reflection> items;

  factory ReflectionsFile.fromJson(Map<String, dynamic> m) => ReflectionsFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', Reflection.fromJson),
      );
  static ReflectionsFile parse(String json) =>
      ReflectionsFile.fromJson(_decode(json));
}

// ---- faq.json ----

class FaqItem implements TextItem {
  const FaqItem(this.id, this.patterns, this.text);
  @override
  final String id;
  final List<String> patterns;
  @override
  final String text;

  static FaqItem? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final text = _strOrNull(m, 'text');
    if (id == null || text == null) return null;
    return FaqItem(id, _strList(m, 'patterns'), text);
  }
}

class FaqFile {
  const FaqFile({this.version = 1, this.items = const []});
  final int version;
  final List<FaqItem> items;

  factory FaqFile.fromJson(Map<String, dynamic> m) => FaqFile(
        version: _int(m, 'version', 1),
        items: _objList(m, 'items', FaqItem.fromJson),
      );
  static FaqFile parse(String json) => FaqFile.fromJson(_decode(json));
}

// ---- lexicon.json / triggers.json ----

class LexiconEntry {
  const LexiconEntry({
    required this.emotion,
    this.terms = const [],
    this.quote,
    this.weight = 1,
  });

  /// EmotionTag の名前。
  final String emotion;
  final List<String> terms;

  /// 反映文の {w} に差し込む引用語（任意）。
  final String? quote;
  final int weight;

  static LexiconEntry? fromJson(Map<String, dynamic> m) {
    final emotion = _strOrNull(m, 'emotion');
    if (emotion == null) return null;
    return LexiconEntry(
      emotion: emotion,
      terms: _strList(m, 'terms'),
      quote: _strOrNull(m, 'quote'),
      weight: _int(m, 'weight', 1),
    );
  }
}

class Lexicon {
  const Lexicon({
    this.version = 1,
    this.entries = const [],
    this.intensifiers = const [],
    this.negations = const [],
    this.contrasts = const [],
  });

  final int version;
  final List<LexiconEntry> entries;
  final List<String> intensifiers;
  final List<String> negations;
  final List<String> contrasts;

  factory Lexicon.fromJson(Map<String, dynamic> m) => Lexicon(
        version: _int(m, 'version', 1),
        entries: _objList(m, 'entries', LexiconEntry.fromJson),
        intensifiers: _strList(m, 'intensifiers'),
        negations: _strList(m, 'negations'),
        contrasts: _strList(m, 'contrasts'),
      );
  static Lexicon parse(String json) => Lexicon.fromJson(_decode(json));
}

/// トリガー判定語辞書（キーは "OTHER" / "SELF" / "URGE"）。
class Triggers {
  const Triggers({
    this.version = 1,
    this.other = const [],
    this.self = const [],
    this.urge = const [],
  });

  final int version;
  final List<String> other;
  final List<String> self;
  final List<String> urge;

  factory Triggers.fromJson(Map<String, dynamic> m) => Triggers(
        version: _int(m, 'version', 1),
        other: _strList(m, 'OTHER'),
        self: _strList(m, 'SELF'),
        urge: _strList(m, 'URGE'),
      );
  static Triggers parse(String json) => Triggers.fromJson(_decode(json));
}

// ---- crisis.json ----

/// 危機判定語辞書。他言語へのフォールバックはしない（言語ごとに完結）。
class CrisisLexicon {
  const CrisisLexicon({
    this.version = 1,
    this.direct = const [],
    this.indirect = const [],
    this.harm = const [],
    this.abuse = const [],
    this.harassment = const [],
    this.soft = const [],
    this.caution = const [],
    this.exclusions = const [],
  });

  final int version;
  final List<String> direct;
  final List<String> indirect;
  final List<String> harm;
  final List<String> abuse;
  final List<String> harassment;
  final List<String> soft;
  final List<String> caution;
  final List<String> exclusions;

  factory CrisisLexicon.fromJson(Map<String, dynamic> m) => CrisisLexicon(
        version: _int(m, 'version', 1),
        direct: _strList(m, 'direct'),
        indirect: _strList(m, 'indirect'),
        harm: _strList(m, 'harm'),
        abuse: _strList(m, 'abuse'),
        harassment: _strList(m, 'harassment'),
        soft: _strList(m, 'soft'),
        caution: _strList(m, 'caution'),
        exclusions: _strList(m, 'exclusions'),
      );
  static CrisisLexicon parse(String json) => CrisisLexicon.fromJson(_decode(json));
}

// ---- wheel.json ----

class WheelChild {
  const WheelChild(this.id, this.label, this.emotion);
  final String id;
  final String label;
  final String emotion;

  static WheelChild? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final label = _strOrNull(m, 'label');
    if (id == null || label == null) return null;
    return WheelChild(id, label, _str(m, 'emotion'));
  }
}

class WheelCore {
  const WheelCore(this.id, this.label, this.emotion, {this.children = const []});
  final String id;
  final String label;
  final String emotion;
  final List<WheelChild> children;

  static WheelCore? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final label = _strOrNull(m, 'label');
    if (id == null || label == null) return null;
    return WheelCore(id, label, _str(m, 'emotion'),
        children: _objList(m, 'children', WheelChild.fromJson));
  }
}

class WheelFile {
  const WheelFile({this.version = 1, this.core = const []});
  final int version;
  final List<WheelCore> core;

  factory WheelFile.fromJson(Map<String, dynamic> m) => WheelFile(
        version: _int(m, 'version', 1),
        core: _objList(m, 'core', WheelCore.fromJson),
      );
  static WheelFile parse(String json) => WheelFile.fromJson(_decode(json));
}

// ---- common/helplines.json ----

/// 言語別の文字列。ファイルは en / ja を持つ（es・pt があれば使い、無ければ en）。
class LocalizedText {
  const LocalizedText({required this.en, required this.ja, this.es, this.pt});

  final String en;
  final String ja;
  final String? es;
  final String? pt;

  /// [lang] の文。無い・空なら en。
  String forLang(AppLang lang) {
    final String? v;
    switch (lang) {
      case AppLang.ja:
        v = ja;
      case AppLang.es:
        v = es;
      case AppLang.pt:
        v = pt;
      case AppLang.en:
        v = en;
    }
    return (v == null || v.isEmpty) ? en : v;
  }

  factory LocalizedText.fromJson(Map<String, dynamic> m) => LocalizedText(
        en: _str(m, 'en'),
        ja: _str(m, 'ja'),
        es: _strOrNull(m, 'es'),
        pt: _strOrNull(m, 'pt'),
      );
}

/// 相談窓口の 1 行。[kind] は "CRISIS" / "ABUSE"。
class HelplineEntry {
  const HelplineEntry({
    required this.id,
    required this.name,
    required this.number,
    this.sms,
    required this.hours,
    required this.kind,
  });

  final String id;
  final LocalizedText name;
  final String number;
  final String? sms;
  final LocalizedText hours;
  final String kind;

  static HelplineEntry? fromJson(Map<String, dynamic> m) {
    final id = _strOrNull(m, 'id');
    final number = _strOrNull(m, 'number');
    if (id == null || number == null) return null;
    return HelplineEntry(
      id: id,
      name: LocalizedText.fromJson(_asMap(m['name'])),
      number: number,
      sms: _strOrNull(m, 'sms'),
      hours: LocalizedText.fromJson(_asMap(m['hours'])),
      kind: _str(m, 'kind', 'CRISIS'),
    );
  }
}

class HelplineCountry {
  const HelplineCountry(this.code, {this.lines = const []});
  final String code;
  final List<HelplineEntry> lines;

  static HelplineCountry? fromJson(Map<String, dynamic> m) {
    final code = _strOrNull(m, 'code');
    if (code == null) return null;
    return HelplineCountry(code, lines: _objList(m, 'lines', HelplineEntry.fromJson));
  }
}

class Helplines {
  const Helplines({this.version = 1, this.countries = const [], this.fallbackUrl = ''});

  final int version;
  final List<HelplineCountry> countries;

  /// 国が見つからないときに案内する URL（findahelpline.com）。
  final String fallbackUrl;

  List<String> get countryCodes => countries.map((c) => c.code).toList();

  HelplineCountry? country(String code) {
    for (final c in countries) {
      if (c.code == code) return c;
    }
    return null;
  }

  factory Helplines.fromJson(Map<String, dynamic> m) => Helplines(
        version: _int(m, 'version', 1),
        countries: _objList(m, 'countries', HelplineCountry.fromJson),
        fallbackUrl: _str(m, 'fallbackUrl'),
      );
  static Helplines parse(String json) => Helplines.fromJson(_decode(json));
}

// ---- common/output_gate.json ----

class CjkHashEntry {
  const CjkHashEntry(this.len, this.sha256);
  final int len;
  final String sha256;

  static CjkHashEntry? fromJson(Map<String, dynamic> m) {
    final len = _intOrNull(m, 'len');
    final hash = _strOrNull(m, 'sha256');
    if (len == null || hash == null) return null;
    return CjkHashEntry(len, hash);
  }
}

/// 出力ゲート（禁止語の SHA-256 ハッシュのみ。平文は持たない）。
class OutputGateData {
  const OutputGateData({
    this.version = 1,
    this.algo = 'sha256',
    this.latin = const [],
    this.cjk = const [],
  });

  final int version;
  final String algo;
  final List<String> latin;
  final List<CjkHashEntry> cjk;

  factory OutputGateData.fromJson(Map<String, dynamic> m) => OutputGateData(
        version: _int(m, 'version', 1),
        algo: _str(m, 'algo', 'sha256'),
        latin: _strList(m, 'latin'),
        cjk: _objList(m, 'cjk', CjkHashEntry.fromJson),
      );
  static OutputGateData parse(String json) => OutputGateData.fromJson(_decode(json));
}
