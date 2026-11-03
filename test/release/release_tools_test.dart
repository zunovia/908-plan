import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/release_tools.dart';
import 'package:zero_app/features/release/domain/tts_lang.dart';

void main() {
  // Kotlin CleaningViewModelTest の words。
  const words = WordsFile(
    four: ['sorry', 'forgive', 'thank_you', 'love'],
    items: [
      WordItem('sorry', "I'm sorry"),
      WordItem('forgive', 'Please forgive me'),
      WordItem('thank_you', 'Thank you'),
      WordItem('love', 'I love you'),
      WordItem('like_so_much', 'I like you so much'),
      WordItem('idk', "I don't know"),
    ],
  );
  const usualSet = ["I'm sorry", 'Please forgive me', 'Thank you', 'I love you'];

  group('ReleaseWordSet (Kotlin CleaningViewModelTest の言葉の決め方)', () {
    test('loads the four phrases in full', () {
      final ws = ReleaseWordSet.build(words, const []);
      expect(ws.initial(ReleaseMode.WORDS4, savedTool: 'set', ownTools: const []).words, usualSet);
    });

    test('one word mode cycles the one-word pool', () {
      final ws = ReleaseWordSet.build(words, const []);
      expect(ws.initial(ReleaseMode.WORDS1, savedTool: 'set', ownTools: const []).words,
          ['Thank you', 'I love you', 'I like you so much', "I'm sorry", 'Please forgive me']);
    });

    test('tools list the usual set, each word alone, then own tools', () {
      final ws = ReleaseWordSet.build(words, const []);
      final init = ws.initial(ReleaseMode.WORDS4, savedTool: 'set', ownTools: const ['Press the Delete key']);
      expect(init.tools.map((t) => t.id).toList(), [
        'set',
        'word:sorry',
        'word:forgive',
        'word:thank_you',
        'word:love',
        'word:like_so_much',
        'word:idk',
        'own:Press the Delete key',
      ]);
      expect(init.selectedTool, ReleaseTools.set);
      expect(init.tools.last.own, isTrue);
    });

    test('the saved tool is used next time, also for the one word', () {
      final ws = ReleaseWordSet.build(words, const []);
      expect(ws.initial(ReleaseMode.WORDS4, savedTool: 'word:thank_you', ownTools: const []).words, ['Thank you']);
      expect(ws.initial(ReleaseMode.WORDS1, savedTool: 'word:thank_you', ownTools: const []).words, ['Thank you']);
    });

    test('choosing the set again shows the usual set for the mode', () {
      final ws = ReleaseWordSet.build(words, const []);
      final tools = ws.toolOptions(ReleaseMode.WORDS4, const []);
      final set = tools.firstWhere((t) => t.id == ReleaseTools.set);
      expect(ws.wordsForTool(ReleaseMode.WORDS4, set), usualSet);
      final ty = tools.firstWhere((t) => t.id == 'word:thank_you');
      expect(ws.wordsForTool(ReleaseMode.WORDS4, ty), ['Thank you']);
    });

    test('I-dont-know keeps its own word even with a saved tool', () {
      final ws = ReleaseWordSet.build(words, const []);
      final init = ws.initial(ReleaseMode.IDK, savedTool: 'word:thank_you', ownTools: const []);
      expect(init.words, ["I don't know"]);
      expect(init.selectedTool, '');
      expect(init.tools, isEmpty);
    });

    test('a saved tool that no longer exists falls back to the usual set', () {
      final ws = ReleaseWordSet.build(words, const []);
      final init = ws.initial(ReleaseMode.WORDS4, savedTool: 'own:Gone', ownTools: const []);
      expect(init.selectedTool, ReleaseTools.set);
      expect(init.words, usualSet);
    });

    test('custom words replace the default set and the one-word pool', () {
      final ws = ReleaseWordSet.build(words, const ['Let go', 'Thank you']);
      expect(ws.initial(ReleaseMode.WORDS4, savedTool: 'set', ownTools: const []).words, ['Let go', 'Thank you']);
      expect(ws.initial(ReleaseMode.WORDS1, savedTool: 'set', ownTools: const []).words, ['Let go', 'Thank you']);
    });

    test('cross shows the mark and PRE shows the card words', () {
      final ws = ReleaseWordSet.build(words, const []);
      expect(ws.baseWordsFor(ReleaseMode.CROSS), ['×']);
      const card = CardItem(id: 'p1', kind: CardKind.PRE, text: 't', words: ['thank_you', 'unknown_id']);
      expect(ws.baseWordsFor(ReleaseMode.PRE, card: card), ['Thank you', 'unknown_id']);
      expect(ws.baseWordsFor(ReleaseMode.PRE), usualSet);
    });

    test('quick goal is 3 and modes map to session kinds', () {
      expect(ReleaseWordSet.quickGoal, 3);
      expect(ReleaseMode.fromName('WORDS1'), ReleaseMode.WORDS1);
      expect(ReleaseMode.fromName('bogus'), ReleaseMode.WORDS4);
      expect(ReleaseMode.CROSS.sessionKind, SessionKind.CROSS);
    });

    test('tts language follows the script of the word', () {
      expect(ttsLangFor('Ice Blue', AppLang.ja), AppLang.en);
      expect(ttsLangFor("I'm sorry", AppLang.ja), AppLang.en);
      expect(ttsLangFor('消去', AppLang.en), AppLang.ja);
      expect(ttsLangFor('アイスブルー', AppLang.en), AppLang.ja);
      expect(ttsLangFor('★', AppLang.en), AppLang.en);
      expect(ttsLangFor('', AppLang.ja), AppLang.ja);
      expect(ttsLangFor('Gracias', AppLang.es), AppLang.es);
      expect(ttsLangFor('Obrigado', AppLang.pt), AppLang.pt);
      expect(ttsLocaleTag(AppLang.ja), 'ja-JP');
    });
  });

  group('ReleaseTools.resolve', () {
    test('returns null when there are no options', () {
      expect(ReleaseTools.resolve('set', const []), isNull);
    });
  });

  group('OwnTools (Kotlin OwnToolsTest)', () {
    test('normalize folds newlines and spaces, drops blanks and duplicates, caps length and count', () {
      final input = [
        '  パソコンの\nDelete キーを押す ',
        '',
        '   ',
        'パソコンの Delete キーを押す',
        'x' * 60,
        for (var i = 1; i <= 20; i++) 't$i',
      ];
      final out = OwnTools.normalize(input);
      expect(out.length, OwnTools.maxTools);
      expect(out[0], 'パソコンの Delete キーを押す');
      expect(out[1].length, OwnTools.maxLength);
      expect(out[2], 't1');
    });

    test('encode and decode round-trip', () {
      const tools = ['Press the Delete key', '消しゴムで消す', 'a, b / c'];
      expect(OwnTools.decode(OwnTools.encode(tools)), tools);
      expect(OwnTools.decode(null), isEmpty);
      expect(OwnTools.decode('  '), isEmpty);
    });

    test('clip does not split a surrogate pair', () {
      final s = '${'a' * 39}😀';
      expect(OwnTools.clip(s), 'a' * 39);
    });
  });

  group('CustomWords (Kotlin CustomWordsTest)', () {
    test('normalize trims, drops blanks, caps length and count', () {
      final input = ['  ありがとう ', '', '   ', 'a,b', 'x' * 40, for (var i = 1; i <= 10; i++) 'w$i'];
      final out = CustomWords.normalize(input);
      expect(out.length, CustomWords.maxWords);
      expect(out[0], 'ありがとう');
      expect(out[1], 'a,b');
      expect(out[2].length, CustomWords.maxLength);
    });

    test('encode and decode round-trip and keep commas', () {
      const w = ['Ice Blue', 'Delete', 'a,b'];
      expect(CustomWords.decode(CustomWords.encode(w)), w);
      expect(CustomWords.decode(null), isEmpty);
      expect(CustomWords.decode('   '), isEmpty);
      expect(CustomWords.decode(CustomWords.encode(const [])), isEmpty);
    });
  });

  group('RecentIds (Kotlin RecentIdsTest)', () {
    test('push appends new id to the end', () => expect(RecentIds.push(['a', 'b'], 'c'), ['a', 'b', 'c']));
    test('push keeps only the last maxSize ids', () {
      expect(RecentIds.push(['1', '2', '3', '4', '5', '6', '7'], '8', maxSize: 7), ['2', '3', '4', '5', '6', '7', '8']);
    });
    test('push moves a duplicate id to the end', () => expect(RecentIds.push(['a', 'b', 'c'], 'a'), ['b', 'c', 'a']));
    test('push with blank id truncates without adding', () {
      expect(RecentIds.push(['a', 'b', 'c'], '', maxSize: 2), ['b', 'c']);
    });
    test('encode and decode round trip', () => expect(RecentIds.decode(RecentIds.encode(['x', 'y', 'z'])), ['x', 'y', 'z']));
    test('decode handles null and blank input', () {
      expect(RecentIds.decode(null), isEmpty);
      expect(RecentIds.decode(''), isEmpty);
      expect(RecentIds.decode('   '), isEmpty);
    });
  });

  group('TriggerCue / TimeText / TimeRules / LoopSpeed / AppLang', () {
    test('TriggerCue encode and decode round trip, unknown names dropped', () {
      const cues = [TriggerCue.BEFORE_SLEEP, TriggerCue.WHEN_IRRITATED];
      final raw = TriggerCue.encode(cues);
      expect(raw, 'BEFORE_SLEEP\nWHEN_IRRITATED');
      expect(TriggerCue.decode(raw), cues);
      expect(TriggerCue.decode('ON_WAKING\nBOGUS\n\nON_WAKING'), [TriggerCue.ON_WAKING]);
      expect(TriggerCue.decode(null), isEmpty);
      expect(TriggerCue.BEFORE_SLEEP.timed, isTrue);
      expect(TriggerCue.ON_COMMUTE.timed, isFalse);
    });

    test('TimeText parse and format', () {
      expect(TimeText.parse('22:00'), (hour: 22, minute: 0));
      expect(TimeText.parse('07:30'), (hour: 7, minute: 30));
      expect(TimeText.parse('0:0'), (hour: 0, minute: 0));
      for (final bad in ['', '24:00', '12:60', 'abc', '12']) {
        expect(TimeText.parse(bad), isNull, reason: bad);
      }
      expect(TimeText.format(7, 5), '07:05');
      expect(TimeText.format(30, 90), '23:59');
      expect(TimeText.format(-5, -5), '00:00');
    });

    test('isNightHour is true from 0 to 4', () {
      for (var h = 0; h < 24; h++) {
        expect(TimeRules.isNightHour(h), h <= 4, reason: 'hour=$h');
      }
    });

    test('LoopSpeed from settings', () {
      expect(LoopSpeed.fromSetting('normal'), LoopSpeed.NORMAL);
      expect(LoopSpeed.fromSetting('off'), LoopSpeed.OFF);
      expect(LoopSpeed.fromSetting('???'), LoopSpeed.OFF);
      expect(LoopSpeed.SLOW.intervalMillis, 2500);
      expect(LoopSpeed.FAST.settingValue, 'fast');
    });

    test('AppLang.fromTag and contentLangFor', () {
      expect(AppLang.fromTag('ja-JP'), AppLang.ja);
      expect(AppLang.fromTag('pt_BR'), AppLang.pt);
      expect(AppLang.fromTag('fr'), isNull);
      expect(AppLang.fromTag(''), isNull);
      expect(contentLangFor('es', 'ja'), AppLang.es);
      expect(contentLangFor('system', 'pt'), AppLang.pt);
      expect(contentLangFor('system', 'fr'), AppLang.en);
    });
  });
}
