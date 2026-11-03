import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/presentation/release_tts.dart';

class _MockTts extends Mock implements FlutterTts {}

void main() {
  late _MockTts mock;
  late ReleaseTts tts;

  setUp(() {
    mock = _MockTts();
    tts = ReleaseTts(create: () => mock);
    when(() => mock.stop()).thenAnswer((_) async => 1);
    when(() => mock.speak(any())).thenAnswer((_) async => 1);
  });

  test('sets the language once, then speaks', () async {
    when(() => mock.setLanguage(any())).thenAnswer((_) async => 1);
    await tts.speak('ありがとう', AppLang.ja);
    await tts.speak('ごめんなさい', AppLang.ja);
    verify(() => mock.setLanguage('ja-JP')).called(1);
    verify(() => mock.speak('ありがとう')).called(1);
    verify(() => mock.speak('ごめんなさい')).called(1);
    expect(tts.languageMissing.value, isFalse);

    await tts.speak('obrigado', AppLang.pt);
    verify(() => mock.setLanguage('pt-BR')).called(1);
  });

  test('a missing voice is reported and nothing is spoken', () async {
    when(() => mock.setLanguage(any())).thenAnswer((_) async => 0);
    await tts.speak('gracias', AppLang.es);
    expect(tts.languageMissing.value, isTrue);
    verifyNever(() => mock.speak(any()));
  });

  test('a failing engine never throws', () async {
    when(() => mock.setLanguage(any())).thenThrow(Exception('no engine'));
    await tts.speak('thank you', AppLang.en);
    expect(tts.languageMissing.value, isTrue);
    when(() => mock.stop()).thenThrow(Exception('no engine'));
    await tts.stop();
  });

  test('empty text does nothing', () async {
    await tts.speak('  ', AppLang.en);
    verifyZeroInteractions(mock);
  });
}
