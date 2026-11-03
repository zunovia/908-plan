import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/safety_gate.dart';

import 'release_test_helpers.dart';

void main() {
  group('SafetyGate synthetic (Kotlin SafetyGateTest)', () {
    test('direct match is CRISIS', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(direct: ['want to die'])});
      final r = gate.checkInput('I want to die tonight');
      expect(r.level, SafetyLevel.CRISIS);
      expect(r.abuseContext, isFalse);
    });

    test('abuse match is CRISIS and sets abuseContext', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(abuse: ['he hits me'])});
      final r = gate.checkInput('he hits me every night');
      expect(r.level, SafetyLevel.CRISIS);
      expect(r.abuseContext, isTrue);
    });

    test('harassment match sets abuseContext without escalating level', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(harassment: ['stalking me'])});
      final r = gate.checkInput('someone is stalking me online');
      expect(r.level, SafetyLevel.OK);
      expect(r.abuseContext, isTrue);
    });

    test('soft single term is CRISIS_SOFT', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(soft: ['hopeless'])});
      expect(gate.checkInput('everything feels hopeless').level, SafetyLevel.CRISIS_SOFT);
    });

    test('caution needs at least two terms', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(caution: ['tired', 'alone'])});
      expect(gate.checkInput("I'm so tired").level, SafetyLevel.OK);
      expect(gate.checkInput("I'm so tired and alone").level, SafetyLevel.CRISIS_SOFT);
    });

    test('exclusions remove phrase before matching', () {
      const gate = SafetyGate({
        AppLang.en: CrisisLexicon(soft: ['die'], exclusions: ['die in a movie']),
      });
      expect(gate.checkInput('the hero will die in a movie tonight').level, SafetyLevel.OK);
    });

    test('isFreeTextAllowed reflects available dicts', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon()});
      expect(gate.isFreeTextAllowed(AppLang.en), isTrue);
      expect(gate.isFreeTextAllowed(AppLang.ja), isFalse);
      expect(gate.isFreeTextAllowed(null), isFalse);
    });

    test('check() is an alias of checkInput()', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(direct: ['want to die'])});
      expect(gate.check('i want to die', AppLang.en).level, SafetyLevel.CRISIS);
    });

    test('text without any dictionary script is OK', () {
      const gate = SafetyGate({AppLang.en: CrisisLexicon(direct: ['want to die'])});
      expect(gate.checkInput('死にたい').level, SafetyLevel.OK);
      expect(gate.checkInput('').level, SafetyLevel.OK);
    });
  });

  group('SafetyGate fillers (Kotlin SafetyGateFillerTest)', () {
    const en = CrisisLexicon(
      direct: ['want to die', 'kill myself'],
      indirect: ['want it all to end', "don't want to live", 'want everything to end'],
      exclusions: ['want this meeting to end', 'this deadline is killing me'],
    );
    const ja = CrisisLexicon(
      direct: ['死にたい'],
      indirect: ['全部終わりにしたい', '消えたい', '生きていても仕方ない'],
      exclusions: ['会議を終わりにしたい', '死ぬほど眠い'],
    );
    const gate = SafetyGate({AppLang.en: en, AppLang.ja: ja});

    const crisisCases = [
      'I just want it all to end',
      'i really just want it all to end',
      'I want to just die',
      'I really really want to die',
      'honestly i dont want to live anymore',
      'I kinda want everything to end',
      'もう本当に全部終わりにしたい',
      'ほんとただ消えたい',
      '正直もう死にたい',
      '生きていてもほんとうに仕方ない',
    ];
    const safeCases = [
      'I just want this meeting to end',
      'this deadline is killing me honestly',
      'I really want the day to end well',
      'もう会議を終わりにしたい',
      '死ぬほど眠い、ほんとに',
    ];

    for (final t in crisisCases) {
      test('CRISIS: $t', () => expect(gate.checkInput(t).level, SafetyLevel.CRISIS));
    }
    for (final t in safeCases) {
      test('OK: $t', () => expect(gate.checkInput(t).level, SafetyLevel.OK));
    }
  });

  group('SafetyGate Spanish (Kotlin SafetyGateSpanishTest)', () {
    const es = CrisisLexicon(
      direct: ['quiero hacerme daño', 'estarían mejor sin mí'],
      exclusions: ['me muero de risa'],
    );
    const gate = SafetyGate({AppLang.es: es});

    test('accented dictionary terms match accented and unaccented input', () {
      for (final t in [
        'Quiero hacerme daño',
        'quiero hacerme dano',
        'Estarían mejor sin mí',
        'estarian mejor sin mi',
      ]) {
        expect(gate.checkInput(t).level, SafetyLevel.CRISIS, reason: t);
      }
    });

    test('ordinary spanish stays OK', () {
      expect(gate.checkInput('Hoy me muero de risa con mi mamá').level, SafetyLevel.OK);
    });

    test('production spanish dictionary classifies representative phrases', () {
      final real = SafetyGate({
        AppLang.es: CrisisLexicon.parse(readUtf8(releaseAsset('es', 'crisis.json'))),
      });
      for (final t in [
        'Ya no puedo más, quiero quitarme la vida',
        'Creo que estarían mejor sin mí',
        'Él me pega cuando llega borracho',
        'Voy a hacerle daño si vuelve a hablarme así',
        'no quiero seguir viviendo',
      ]) {
        expect(real.checkInput(t).level, SafetyLevel.CRISIS, reason: t);
      }
      for (final t in ['A veces una parte de mí quiere desaparecer', 'Estoy agotada y al límite']) {
        expect(real.checkInput(t).level, SafetyLevel.CRISIS_SOFT, reason: t);
      }
      for (final t in [
        'Me muero de risa con esta serie',
        'Quiero que termine la reunión de hoy',
        'Hoy llegué tarde al trabajo y me enfadé',
      ]) {
        expect(real.checkInput(t).level, SafetyLevel.OK, reason: t);
      }
    });
  });

  group('SafetyGate fixtures (safety_cases.json × production en/ja crisis.json)', () {
    final fixture = jsonDecode(readUtf8(releaseFixture('safety_cases.json'))) as Map<String, dynamic>;
    final gate = SafetyGate({
      AppLang.en: CrisisLexicon.parse(readUtf8(releaseAsset('en', 'crisis.json'))),
      AppLang.ja: CrisisLexicon.parse(readUtf8(releaseAsset('ja', 'crisis.json'))),
    });

    for (final lang in ['en', 'ja']) {
      final cases = (fixture[lang] as Map<String, dynamic>?) ?? const {};
      for (final kind in ['crisis', 'safe']) {
        for (final raw in (cases[kind] as List? ?? const [])) {
          final c = raw as Map<String, dynamic>;
          final text = c['text'] as String;
          final expectLevel = SafetyLevel.values.byName(c['expect'] as String);
          final abuse = c['abuse'] as bool? ?? false;
          test('[$lang][$kind] $text', () {
            final r = gate.checkInput(text);
            expect(r.level, expectLevel, reason: text);
            if (kind == 'crisis') expect(r.abuseContext, abuse, reason: 'abuse mismatch: $text');
          });
        }
      }
    }
  });
}
