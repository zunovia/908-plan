// QA round 1: 実辞書（ja/en/es/pt）での危機表現・慣用句の抜き取り検査。

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/data/content_repository.dart';
import 'package:zero_app/features/release/data/release_domain.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/safety_gate.dart';

import 'release_test_helpers.dart';

void main() {
  late SafetyGate gate;

  setUpAll(() async {
    final bundle = await ContentRepository(const FileContentLoader()).bundle();
    gate = ReleaseDomain.build(bundle).safetyGate;
  });

  const crisis = [
    // pt
    'quero morrer', 'eu quero me matar', 'Não aguento mais viver, quero acabar com a minha vida',
    'penso em suicídio', 'vou me matar hoje', 'quero tirar a minha vida', 'não quero mais viver',
    'quero me machucar', 'vou me cortar', 'melhor se eu estivesse morto', 'vou matar ele',
    'meu marido me bate todo dia', 'quero me jogar da ponte', 'queria não existir',
    'não quero estar vivo', 'prefiro estar morta', 'me cortei', 'vou me ferir', 'penso em me machucar',
    // es
    'quiero morir', 'me quiero matar', 'voy a quitarme la vida', 'pienso en suicidarme',
    'mi pareja me golpea', 'mejor no existir',
    // en
    'I want to kill myself', 'I want to end my life', 'thinking of ending it all',
    // ja
    '死にたい', '自殺を考えている', '首を吊りたい', '自分を傷つけたい', 'あいつを殺す', '親に虐待されている',
  ];

  const safe = [
    'morri de rir', 'estou morrendo de sono', 'esse prazo está me matando', 'vou matar aula hoje',
    'matar a saudade da minha mãe', 'estou cansado hoje', 'quero acabar o trabalho',
    'quero que a semana acabe', 'matar o tempo', 'vou matar a fome', 'estou morto de cansaço',
    'me muero de risa', 'me muero de ganas de verte', 'matar el tiempo', 'estoy cansado',
    'this deadline is killing me', 'I am dying of laughter', 'I want to end this meeting',
    '今日は疲れた', '会議を終わりにしたい', '死ぬほどおいしい', 'お腹が空いた',
  ];

  for (final t in crisis) {
    test('CRISIS: $t', () => expect(gate.checkInput(t).level, SafetyLevel.CRISIS));
  }
  for (final t in safe) {
    test('OK: $t', () => expect(gate.checkInput(t).level, SafetyLevel.OK));
  }
}
