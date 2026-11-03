import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/output_gate.dart';

import 'release_test_helpers.dart';

void main() {
  group('OutputGate synthetic (Kotlin OutputGateTest)', () {
    const latinPhrase = 'zzblockedzz';
    const cjkPhrase = '禁止テスト語';

    OutputGate syntheticGate() {
      final cjkNorm = OutputGate.cjkNorm(cjkPhrase);
      return OutputGate(
        {OutputGate.sha256Hex(latinPhrase)},
        {
          cjkNorm.length: {OutputGate.sha256Hex(cjkNorm)},
        },
      );
    }

    test('sha256Hex matches the known digest', () {
      expect(
        OutputGate.sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('detects exact latin phrase', () {
      expect(syntheticGate().isClean('this contains $latinPhrase inside'), isFalse);
    });

    test('does not flag unrelated latin text', () {
      expect(syntheticGate().isClean('this is a perfectly normal sentence'), isTrue);
    });

    test('detects cjk phrase', () {
      expect(syntheticGate().isClean('これは$cjkPhraseを含む文です'), isFalse);
    });

    test('katakana and hiragana are treated the same', () {
      final norm = OutputGate.cjkNorm('あんぜんなことば');
      final gate = OutputGate(const {}, {
        norm.length: {OutputGate.sha256Hex(norm)},
      });
      expect(gate.isClean('文中にアンゼンナコトバが入っている'), isFalse);
    });

    test('punctuation and separators are ignored in cjk matching', () {
      final norm = OutputGate.cjkNorm('危険語句');
      final gate = OutputGate(const {}, {
        norm.length: {OutputGate.sha256Hex(norm)},
      });
      expect(gate.isClean('これは「危・険　語句」です'), isFalse);
    });

    test('adjacent token concatenation detects split english phrase', () {
      final gate = OutputGate({OutputGate.sha256Hex('forbiddenword')}, const {});
      expect(gate.isClean('this is a forbidden word in the sentence'), isFalse);
    });

    test('empty gate is always clean', () {
      expect(const OutputGate.empty().isClean('anything at all'), isTrue);
    });
  });

  group('OutputGate with the real output_gate.json', () {
    final data = OutputGateData.parse(readUtf8(releaseCommonAsset('output_gate.json')));
    final gate = OutputGate.from(data);

    test('real output_gate.json is not empty', () {
      expect(data.latin.isNotEmpty || data.cjk.isNotEmpty, isTrue);
    });

    // 同梱するすべての文面がゲートを通ること（en / ja / es、pt は存在すれば）。
    for (final lang in ['en', 'ja', 'es', 'pt']) {
      final texts = _collectTexts(lang);
      test('[$lang] every bundled text passes the output gate (${texts.length} texts)', () {
        final flagged = [
          for (final e in texts.entries)
            if (!gate.isClean(e.value)) '${e.key} -> ${e.value}',
        ];
        expect(flagged, isEmpty, reason: flagged.join('\n'));
      });
    }
  });
}

Map<String, String> _collectTexts(String lang) {
  final out = <String, String>{};
  void ifExists(String name, void Function(String json) add) {
    final f = releaseAsset(lang, name);
    if (f.existsSync()) add(readUtf8(f));
  }

  ifExists('cards.json', (j) {
    for (final c in CardsFile.parse(j).cards) {
      out['card:${c.id}:text'] = c.text;
      final p = c.prompt;
      if (p != null) out['card:${c.id}:prompt'] = p;
    }
  });
  ifExists('replay.json', (j) {
    for (final i in ReplayFile.parse(j).items) {
      out['replay:${i.id}'] = i.text;
    }
  });
  ifExists('child.json', (j) {
    for (final i in ChildFile.parse(j).items) {
      out['child:${i.id}'] = i.text;
    }
  });
  ifExists('surrender.json', (j) {
    for (final i in SurrenderFile.parse(j).items) {
      out['surrender:${i.id}'] = i.text;
    }
  });
  ifExists('reflections.json', (j) {
    for (final i in ReflectionsFile.parse(j).items) {
      out['reflection:${i.id}'] = i.needsWord ? i.text.replaceAll('{w}', 'word') : i.text;
    }
  });
  ifExists('affirmations.json', (j) {
    for (final i in AffirmationsFile.parse(j).items) {
      out['affirmation:${i.id}'] = i.text;
    }
  });
  ifExists('faq.json', (j) {
    for (final i in FaqFile.parse(j).items) {
      out['faq:${i.id}'] = i.text;
    }
  });
  ifExists('notes.json', (j) {
    for (final i in NotesFile.parse(j).items) {
      out['note:${i.id}'] = i.text;
    }
  });
  ifExists('notifications.json', (j) {
    for (final i in NotificationsFile.parse(j).items) {
      out['notification:${i.id}'] = i.text;
    }
  });
  ifExists('quotes.json', (j) {
    for (final i in QuotesFile.parse(j).items) {
      out['quote:${i.id}'] = i.text;
    }
  });
  ifExists('today.json', (j) {
    for (final i in TodayFile.parse(j).items) {
      out['today:${i.id}'] = i.text;
    }
  });
  ifExists('words.json', (j) {
    for (final i in WordsFile.parse(j).items) {
      out['word:${i.id}'] = i.text;
    }
  });
  ifExists('wheel.json', (j) {
    for (final core in WheelFile.parse(j).core) {
      out['wheel:${core.id}'] = core.label;
      for (final ch in core.children) {
        out['wheel:${ch.id}'] = ch.label;
      }
    }
  });
  return out;
}
