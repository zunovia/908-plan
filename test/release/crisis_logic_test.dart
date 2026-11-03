import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/crisis_logic.dart';
import 'package:zero_app/features/release/domain/models.dart';

import 'release_test_helpers.dart';

HelplineEntry entry(String id, String kind) => HelplineEntry(
      id: id,
      name: LocalizedText(en: id, ja: id),
      number: '000',
      hours: const LocalizedText(en: '24/7', ja: '24時間'),
      kind: kind,
    );

void main() {
  const codes = ['JP', 'US', 'GB'];

  group('CrisisLogic (Kotlin CrisisLogicTest)', () {
    test('matches an available country directly', () {
      expect(CrisisLogic.resolveInitialCountryCodeFrom('US', codes), 'US');
    });
    test('normalizes UK to GB', () {
      expect(CrisisLogic.resolveInitialCountryCodeFrom('UK', codes), 'GB');
    });
    test('is case insensitive', () {
      expect(CrisisLogic.resolveInitialCountryCodeFrom('us', codes), 'US');
    });
    test('falls back to OTHER when no match', () {
      expect(CrisisLogic.resolveInitialCountryCodeFrom('FR', codes), otherCountryCode);
    });

    test('sortedLines keeps original order when abuse is false', () {
      final lines = [entry('a', 'CRISIS'), entry('b', 'ABUSE'), entry('c', 'CRISIS')];
      expect(CrisisLogic.sortedLines(lines, abuse: false).map((e) => e.id), ['a', 'b', 'c']);
    });

    test('sortedLines moves ABUSE lines first when abuse is true (stable)', () {
      final lines = [entry('a', 'CRISIS'), entry('b', 'ABUSE'), entry('c', 'CRISIS'), entry('d', 'ABUSE')];
      expect(CrisisLogic.sortedLines(lines, abuse: true).map((e) => e.id), ['b', 'd', 'a', 'c']);
    });

    test('falls back to JP from ja app language when all country candidates are blank', () {
      expect(CrisisLogic.resolveInitialCountryCode(appLang: 'ja', availableCodes: codes), 'JP');
    });

    test('prefers systemCountry over everything else', () {
      expect(
        CrisisLogic.resolveInitialCountryCode(
          systemCountry: 'US',
          simCountry: 'jp',
          networkCountry: 'jp',
          defaultCountry: 'jp',
          appLang: 'ja',
          availableCodes: codes,
        ),
        'US',
      );
    });

    test('falls back to simCountry when systemCountry is blank', () {
      expect(
        CrisisLogic.resolveInitialCountryCode(
          simCountry: 'jp',
          networkCountry: 'gb',
          defaultCountry: 'gb',
          appLang: 'en',
          availableCodes: codes,
        ),
        'JP',
      );
    });

    test('falls back to networkCountry when systemCountry and simCountry are blank', () {
      expect(
        CrisisLogic.resolveInitialCountryCode(
          networkCountry: 'gb',
          defaultCountry: 'us',
          appLang: 'en',
          availableCodes: codes,
        ),
        'GB',
      );
    });

    test('falls back to defaultCountry when system, sim, network are blank', () {
      expect(
        CrisisLogic.resolveInitialCountryCode(defaultCountry: 'us', appLang: 'en', availableCodes: codes),
        'US',
      );
    });

    test('normalizes UK to GB from systemCountry', () {
      expect(
        CrisisLogic.resolveInitialCountryCode(systemCountry: 'UK', appLang: 'en', availableCodes: codes),
        'GB',
      );
    });

    test('OTHER when nothing resolves and app language is not ja', () {
      expect(CrisisLogic.resolveInitialCountryCode(appLang: 'fr', availableCodes: codes), otherCountryCode);
    });

    test('OTHER when the resolved country is not available', () {
      expect(
        CrisisLogic.resolveInitialCountryCode(systemCountry: 'FR', appLang: 'en', availableCodes: codes),
        otherCountryCode,
      );
    });

    test('displayLabel shows UK for GB', () {
      expect(CrisisLogic.displayLabel('GB'), 'UK');
      expect(CrisisLogic.displayLabel('JP'), 'JP');
    });

    test('crisis banner is visible for 24 hours after the last crisis', () {
      const h = 60 * 60 * 1000;
      expect(CrisisLogic.isBannerVisible(0, 1000), isFalse);
      expect(CrisisLogic.isBannerVisible(1000, 1000 + 23 * h), isTrue);
      expect(CrisisLogic.isBannerVisible(1000, 1000 + 24 * h), isFalse);
    });
  });

  group('helplines.json (Kotlin HelplinesContentTest)', () {
    final h = Helplines.parse(readUtf8(releaseCommonAsset('helplines.json')));

    test('contains non-empty lines for JP, US and GB', () {
      for (final code in codes) {
        final c = h.country(code);
        expect(c, isNotNull, reason: code);
        expect(c!.lines, isNotEmpty);
        for (final l in c.lines) {
          expect(l.number.trim(), isNotEmpty, reason: l.id);
        }
      }
    });

    test('has a non-blank fallbackUrl', () {
      expect(h.fallbackUrl.trim(), isNotEmpty);
    });

    test('LocalizedText falls back to en when es / pt are missing', () {
      final line = h.country('JP')!.lines.first;
      expect(line.name.forLang(AppLang.es), line.name.en);
      expect(line.name.forLang(AppLang.ja), line.name.ja);
    });
  });
}
