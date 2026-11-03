import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/english_stemmer.dart';
import 'package:zero_app/features/release/domain/text_normalizer.dart';

void main() {
  group('TextNormalizer (Kotlin TextNormalizerTest)', () {
    test('normBase lowercases and unifies quote marks', () {
      expect(TextNormalizer.normBase('DON’T'), "don't");
      expect(TextNormalizer.normBase('don‘t'), "don't");
      expect(TextNormalizer.normBase('don`t'), "don't");
    });

    test('jaCompact removes whitespace', () {
      expect(TextNormalizer.jaCompact('ありがとう　です'), 'ありがとうです');
    });

    test('enTokens splits on non alnum apostrophe', () {
      expect(TextNormalizer.enTokens("I don't know!"), ['i', "don't", 'know']);
    });

    test('enContainsPhrase matches full phrase only', () {
      expect(TextNormalizer.enContainsPhraseText("I really don't know why", "don't know"), isTrue);
      expect(TextNormalizer.enContainsPhraseText('I really dont know why', "don't know"), isFalse);
    });
  });

  group('TextNormalizer NFKC subset', () {
    test('fullwidth ASCII becomes halfwidth', () {
      expect(TextNormalizer.normBase('ＩＷＡＮＴ　ｔｏ　ｄｉｅ！'), 'iwant to die!');
    });

    test('halfwidth katakana becomes fullwidth with voiced marks composed', () {
      expect(TextNormalizer.nfkc('ｼﾆﾀｲ'), 'シニタイ');
      expect(TextNormalizer.nfkc('ﾀﾞｲｼﾞｮｳﾌﾞ'), 'ダイジョウブ');
      expect(TextNormalizer.nfkc('ﾊﾟﾝ'), 'パン');
      expect(TextNormalizer.nfkc('ｳﾞ'), 'ヴ');
    });

    test('decomposed kana and latin are composed', () {
      expect(TextNormalizer.nfkc('が'), 'が');
      expect(TextNormalizer.nfkc('パ'), 'パ');
      expect(TextNormalizer.nfkc('ñ'), 'ñ');
    });

    test('ellipsis is expanded', () {
      expect(TextNormalizer.nfkc('…'), '...');
    });

    test('foldDiacritics strips latin accents', () {
      expect(TextNormalizer.foldDiacritics('daño mí estarían ação'), 'dano mi estarian acao');
      expect(TextNormalizer.foldDiacritics('é'), 'e');
    });
  });

  group('EnglishStemmer (Kotlin EnglishStemmerTest)', () {
    test('strips ies to y', () => expect(EnglishStemmer.stem('worries'), 'worry'));
    test('strips ied to y', () => expect(EnglishStemmer.stem('worried'), 'worry'));
    test('strips ing and reduces double consonant', () => expect(EnglishStemmer.stem('running'), 'run'));
    test('strips ed and reduces double consonant', () => expect(EnglishStemmer.stem('stopped'), 'stop'));
    test('strips trailing s', () => expect(EnglishStemmer.stem('cats'), 'cat'));
    test('strips trailing ly', () => expect(EnglishStemmer.stem('slowly'), 'slow'));
    test('does not strip when result would be too short', () => expect(EnglishStemmer.stem('as'), 'as'));
    test('stemPhrase stems each word', () {
      expect(EnglishStemmer.stemPhrase('worrying about it'), ['worry', 'about', 'it']);
    });
  });
}
