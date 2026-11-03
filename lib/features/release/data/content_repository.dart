// assets/release/<lang>/*.json と common/*.json を読み込み、キャッシュする。
// Luckarise の AssetContentLoader + ContentRepository を移植。
// 言語別ファイルが無ければ en を使う。ただし crisis.json（危機辞書）だけはフォールバックしない。

import 'package:flutter/services.dart' show rootBundle;

import '../domain/content_models.dart';
import '../domain/models.dart';

/// アセットの読み手（テストでは File から読む実装に差し替える）。見つからなければ null を返す。
abstract class ContentAssetLoader {
  Future<String?> load(String path);
}

/// 本番用: rootBundle から読む。
class RootBundleContentLoader implements ContentAssetLoader {
  const RootBundleContentLoader();

  @override
  Future<String?> load(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      return null;
    }
  }
}

/// 読み込んだ全コンテンツの束。各 Map は「その言語で使う内容」（en フォールバック済み）。
class LoadedContent {
  const LoadedContent({
    required this.cards,
    required this.replay,
    required this.reflections,
    required this.affirmations,
    required this.faqs,
    required this.lexicons,
    required this.triggers,
    required this.crisis,
    required this.outputGate,
    required this.helplines,
    required this.words,
    required this.notes,
    required this.today,
    required this.child,
    required this.surrender,
    required this.quotes,
    required this.notifications,
    required this.wheel,
  });

  final Map<AppLang, List<CardItem>> cards;
  final Map<AppLang, List<ReplayItem>> replay;
  final Map<AppLang, List<Reflection>> reflections;
  final Map<AppLang, List<Affirmation>> affirmations;
  final Map<AppLang, List<FaqItem>> faqs;
  final Map<AppLang, Lexicon> lexicons;
  final Map<AppLang, Triggers> triggers;

  /// 言語ごとに完結し、フォールバックしない危機辞書。無い言語は自由入力を出さない。
  final Map<AppLang, CrisisLexicon> crisis;
  final OutputGateData? outputGate;
  final Helplines? helplines;
  final Map<AppLang, WordsFile> words;
  final Map<AppLang, NotesFile> notes;
  final Map<AppLang, TodayFile> today;
  final Map<AppLang, ChildFile> child;
  final Map<AppLang, SurrenderFile> surrender;
  final Map<AppLang, QuotesFile> quotes;
  final Map<AppLang, NotificationsFile> notifications;
  final Map<AppLang, WheelFile> wheel;
}

class ContentRepository {
  ContentRepository(this.loader, {this.root = 'assets/release', this.langs = AppLang.values});

  final ContentAssetLoader loader;

  /// アセットの根（既定 "assets/release"）。
  final String root;
  final List<AppLang> langs;

  Future<LoadedContent>? _cached;

  /// 全コンテンツ（初回だけ読み込む。失敗した項目は無いものとして扱う）。
  Future<LoadedContent> bundle() => _cached ??= _loadAll();

  /// キャッシュを捨てる（テスト用）。
  void clearCache() => _cached = null;

  Future<List<CardItem>> cards(AppLang lang) async {
    final b = await bundle();
    return b.cards[lang] ?? b.cards[AppLang.en] ?? const [];
  }

  Future<WordsFile?> words(AppLang lang) async => _pick((await bundle()).words, lang);
  Future<NotesFile?> notes(AppLang lang) async => _pick((await bundle()).notes, lang);
  Future<TodayFile?> today(AppLang lang) async => _pick((await bundle()).today, lang);
  Future<ChildFile?> child(AppLang lang) async => _pick((await bundle()).child, lang);
  Future<SurrenderFile?> surrender(AppLang lang) async => _pick((await bundle()).surrender, lang);
  Future<NotificationsFile?> notifications(AppLang lang) async =>
      _pick((await bundle()).notifications, lang);
  Future<WheelFile?> wheel(AppLang lang) async => _pick((await bundle()).wheel, lang);
  Future<List<QuoteItem>> quotes(AppLang lang) async =>
      _pick((await bundle()).quotes, lang)?.items ?? const [];
  Future<List<ReplayItem>> replay(AppLang lang) async {
    final b = await bundle();
    return b.replay[lang] ?? b.replay[AppLang.en] ?? const [];
  }

  Future<Helplines?> helplines() async => (await bundle()).helplines;

  /// その言語の危機辞書（フォールバックしない）。
  Future<CrisisLexicon?> crisis(AppLang lang) async => (await bundle()).crisis[lang];

  T? _pick<T>(Map<AppLang, T> map, AppLang lang) => map[lang] ?? map[AppLang.en];

  Future<LoadedContent> _loadAll() async {
    final cards = <AppLang, List<CardItem>>{};
    final replay = <AppLang, List<ReplayItem>>{};
    final reflections = <AppLang, List<Reflection>>{};
    final affirmations = <AppLang, List<Affirmation>>{};
    final faqs = <AppLang, List<FaqItem>>{};
    final lexicons = <AppLang, Lexicon>{};
    final triggers = <AppLang, Triggers>{};
    final crisis = <AppLang, CrisisLexicon>{};
    final words = <AppLang, WordsFile>{};
    final notes = <AppLang, NotesFile>{};
    final today = <AppLang, TodayFile>{};
    final child = <AppLang, ChildFile>{};
    final surrender = <AppLang, SurrenderFile>{};
    final quotes = <AppLang, QuotesFile>{};
    final notifications = <AppLang, NotificationsFile>{};
    final wheel = <AppLang, WheelFile>{};

    Future<void> put<T>(Map<AppLang, T> into, AppLang lang, String file, T Function(String) parse,
        {bool fallback = true}) async {
      final v = await _load(lang, file, parse, fallback: fallback);
      if (v != null) into[lang] = v;
    }

    for (final lang in langs) {
      await put(cards, lang, 'cards.json', (s) => CardsFile.parse(s).cards);
      await put(replay, lang, 'replay.json', (s) => ReplayFile.parse(s).items);
      await put(reflections, lang, 'reflections.json', (s) => ReflectionsFile.parse(s).items);
      await put(affirmations, lang, 'affirmations.json', (s) => AffirmationsFile.parse(s).items);
      await put(faqs, lang, 'faq.json', (s) => FaqFile.parse(s).items);
      await put(lexicons, lang, 'lexicon.json', Lexicon.parse);
      await put(triggers, lang, 'triggers.json', Triggers.parse);
      // 危機辞書は言語ごとに完結させる（他言語にフォールバックしない）。
      await put(crisis, lang, 'crisis.json', CrisisLexicon.parse, fallback: false);
      await put(words, lang, 'words.json', WordsFile.parse);
      await put(notes, lang, 'notes.json', NotesFile.parse);
      await put(today, lang, 'today.json', TodayFile.parse);
      await put(child, lang, 'child.json', ChildFile.parse);
      await put(surrender, lang, 'surrender.json', SurrenderFile.parse);
      await put(quotes, lang, 'quotes.json', QuotesFile.parse);
      await put(notifications, lang, 'notifications.json', NotificationsFile.parse);
      await put(wheel, lang, 'wheel.json', WheelFile.parse);
    }

    return LoadedContent(
      cards: cards,
      replay: replay,
      reflections: reflections,
      affirmations: affirmations,
      faqs: faqs,
      lexicons: lexicons,
      triggers: triggers,
      crisis: crisis,
      outputGate: await _loadCommon('output_gate.json', OutputGateData.parse),
      helplines: await _loadCommon('helplines.json', Helplines.parse),
      words: words,
      notes: notes,
      today: today,
      child: child,
      surrender: surrender,
      quotes: quotes,
      notifications: notifications,
      wheel: wheel,
    );
  }

  /// 言語別ファイルを読む。無ければ（fallback 時のみ）en。解析に失敗したら null。
  Future<T?> _load<T>(AppLang lang, String file, T Function(String) parse, {required bool fallback}) async {
    var raw = await loader.load('$root/${lang.code}/$file');
    if (raw == null && fallback && lang != AppLang.en) {
      raw = await loader.load('$root/${AppLang.en.code}/$file');
    }
    if (raw == null) return null;
    try {
      return parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<T?> _loadCommon<T>(String file, T Function(String) parse) async {
    final raw = await loader.load('$root/common/$file');
    if (raw == null) return null;
    try {
      return parse(raw);
    } catch (_) {
      return null;
    }
  }
}
