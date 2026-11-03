import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/data/content_repository.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/models.dart';

import 'release_test_helpers.dart';

void main() {
  group('Content parse (Kotlin ContentParserTest): en/ja id sets match', () {
    void idsMatch(String name, Set<String> Function(String json) ids) {
      test('$name parses and ids match between en and ja', () {
        final en = ids(readUtf8(releaseAsset('en', name)));
        final ja = ids(readUtf8(releaseAsset('ja', name)));
        expect(en, isNotEmpty);
        expect(ja, en);
      });
    }

    idsMatch('cards.json', (j) => CardsFile.parse(j).cards.map((c) => c.id).toSet());
    idsMatch('replay.json', (j) => ReplayFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('child.json', (j) => ChildFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('surrender.json', (j) => SurrenderFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('reflections.json', (j) => ReflectionsFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('affirmations.json', (j) => AffirmationsFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('faq.json', (j) => FaqFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('notes.json', (j) => NotesFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('words.json', (j) => WordsFile.parse(j).items.map((i) => i.id).toSet());
    idsMatch('wheel.json', (j) {
      final w = WheelFile.parse(j);
      return {...w.core.map((c) => c.id), for (final c in w.core) ...c.children.map((ch) => ch.id)};
    });
  });

  group('Content parse: every bundled file parses with content', () {
    for (final lang in ['en', 'ja', 'es', 'pt']) {
      final dir = Directory('$releaseAssetsRoot/$lang');
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
        final name = f.uri.pathSegments.last;
        test('[$lang] $name', () {
          final j = readUtf8(f);
          final count = switch (name) {
            'cards.json' => CardsFile.parse(j).cards.length,
            'replay.json' => ReplayFile.parse(j).items.length,
            'child.json' => ChildFile.parse(j).items.length,
            'surrender.json' => SurrenderFile.parse(j).items.length,
            'reflections.json' => ReflectionsFile.parse(j).items.length,
            'affirmations.json' => AffirmationsFile.parse(j).items.length,
            'faq.json' => FaqFile.parse(j).items.length,
            'notes.json' => NotesFile.parse(j).items.length,
            'today.json' => TodayFile.parse(j).items.length,
            'words.json' => WordsFile.parse(j).items.length,
            'wheel.json' => WheelFile.parse(j).core.length,
            'quotes.json' => QuotesFile.parse(j).items.length,
            'notifications.json' => NotificationsFile.parse(j).items.length,
            'lexicon.json' => Lexicon.parse(j).entries.length,
            'triggers.json' => () {
                final t = Triggers.parse(j);
                return t.other.length + t.self.length + t.urge.length;
              }(),
            'crisis.json' => () {
                final c = CrisisLexicon.parse(j);
                return c.direct.length + c.indirect.length + c.soft.length;
              }(),
            _ => -1,
          };
          expect(count, greaterThan(0), reason: '$lang/$name parsed empty or unknown');
        });
      }
    }

    test('common output_gate and helplines parse', () {
      expect(OutputGateData.parse(readUtf8(releaseCommonAsset('output_gate.json'))).latin, isNotEmpty);
      expect(Helplines.parse(readUtf8(releaseCommonAsset('helplines.json'))).countries, isNotEmpty);
    });

    test('words.json four ids all exist in items (en/ja/es)', () {
      for (final lang in ['en', 'ja', 'es']) {
        final w = WordsFile.parse(readUtf8(releaseAsset(lang, 'words.json')));
        for (final id in w.four) {
          expect(w.textFor(id), isNotNull, reason: '$lang four id $id');
        }
      }
    });
  });

  group('Content parse robustness', () {
    test('unknown keys are ignored and broken items are dropped', () {
      final f = CardsFile.parse('{"version":2,"extra":1,"cards":['
          '{"id":"a","kind":"WORDS4","text":"ok","triggers":["URGE","BOGUS"],"scenes":["WORK"],"repeat":7},'
          '{"id":"b","kind":"BOGUS","text":"bad kind"},'
          '{"kind":"WORDS1","text":"no id"},'
          '"not an object"]}');
      expect(f.version, 2);
      expect(f.cards.map((c) => c.id), ['a']);
      expect(f.cards.single.triggers, [TriggerKind.URGE]);
      expect(f.cards.single.scenes, [Scene.WORK]);
      expect(f.cards.single.repeat, 7);
    });

    test('missing lists default to empty', () {
      expect(const CrisisLexicon().direct, isEmpty);
      expect(CrisisLexicon.parse('{}').exclusions, isEmpty);
      expect(WordsFile.parse('{"items":[{"id":"x","text":"X"}]}').four, isEmpty);
    });
  });

  group('WordsFile (Kotlin WordsContentTest)', () {
    const file = WordsFile(
      four: ['thank_you', 'sorry', 'forgive', 'love'],
      items: [
        WordItem('thank_you', 'Thank you'),
        WordItem('sorry', "I'm sorry"),
        WordItem('forgive', 'Please forgive me'),
        WordItem('love', 'I love you'),
        WordItem('like_so_much', 'I like you so much'),
        WordItem('idk', "I don't know"),
      ],
    );

    test('idsToText converts known ids', () {
      expect(file.idsToText(file.four), ['Thank you', "I'm sorry", 'Please forgive me', 'I love you']);
    });
    test('idsToText falls back to the raw id', () => expect(file.idsToText(['unknown_id']), ['unknown_id']));
    test('textFor returns text for a known id', () {
      expect(file.textFor('sorry'), "I'm sorry");
      expect(file.textFor('idk'), "I don't know");
    });
    test('textFor returns null for an unknown id', () => expect(file.textFor('unknown_id'), isNull));
  });

  group('ContentRepository (File loader)', () {
    test('es falls back to en for files it lacks, but crisis.json never falls back', () async {
      final repo = ContentRepository(const FileContentLoader());
      final b = await repo.bundle();
      // es は cards.json を持たない → en のカード
      expect(b.cards[AppLang.es]!.length, b.cards[AppLang.en]!.length);
      // es の words.json は es 自身
      expect(b.words[AppLang.es]!.items.first.text, isNot(b.words[AppLang.en]!.items.first.text));
      // 危機辞書: en/ja/es はあり、pt はファイルが無ければ無い（フォールバックしない）
      expect(b.crisis.containsKey(AppLang.en), isTrue);
      expect(b.crisis.containsKey(AppLang.ja), isTrue);
      expect(b.crisis.containsKey(AppLang.es), isTrue);
      expect(b.crisis.containsKey(AppLang.pt), releaseAsset('pt', 'crisis.json').existsSync());
      expect(b.outputGate, isNotNull);
      expect(b.helplines, isNotNull);
    });

    test('bundle is cached (loaded once)', () async {
      final loader = _CountingLoader();
      final repo = ContentRepository(loader);
      await Future.wait([repo.bundle(), repo.bundle()]);
      final first = loader.count;
      await repo.bundle();
      expect(loader.count, first);
      expect(identical(await repo.bundle(), await repo.bundle()), isTrue);
    });

    test('missing assets give empty maps without throwing', () async {
      final repo = ContentRepository(const FileContentLoader(), root: 'does/not/exist');
      final b = await repo.bundle();
      expect(b.cards, isEmpty);
      expect(b.crisis, isEmpty);
      expect(b.outputGate, isNull);
      expect(await repo.words(AppLang.ja), isNull);
    });
  });
}

class _CountingLoader implements ContentAssetLoader {
  int count = 0;

  @override
  Future<String?> load(String path) async {
    count++;
    return const FileContentLoader().load(path);
  }
}
