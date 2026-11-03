import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zero_app/features/release/presentation/release_ui.dart';

void main() {
  // 2026-11-03 14:05 local time.
  final t = DateTime(2026, 11, 3, 14, 5).millisecondsSinceEpoch;

  // Declared first, so it runs before initializeDateFormatting below: inside
  // the app, flutter_localizations (GlobalMaterialLocalizations) loads the
  // date symbols for the display language by itself.
  testWidgets('in the app the date symbols come from the localization delegates', (tester) async {
    String? label;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          label = relTimeLabel(t, AppLocalizations.of(context).localeName);
          return const SizedBox();
        }),
      ),
    );
    await tester.pump();
    expect(label, '3/11 14:05');
  });

  group('relTimeLabel', () {
    setUpAll(() async {
      for (final l in ['ja', 'en', 'es', 'pt']) {
        await initializeDateFormatting(l);
      }
    });

    test('month/day order and 24-hour time follow the language', () {
      expect(relTimeLabel(t, 'ja'), '11/3 14:05');
      expect(relTimeLabel(t, 'en'), '11/3 14:05');
      expect(relTimeLabel(t, 'es'), '3/11 14:05');
      expect(relTimeLabel(t, 'pt'), '3/11 14:05');
    });

    test('minutes are zero-padded; the hour follows the language (ja: 7:03, en: 07:03)', () {
      final early = DateTime(2026, 1, 9, 7, 3).millisecondsSinceEpoch;
      expect(relTimeLabel(early, 'ja'), '1/9 7:03');
      expect(relTimeLabel(early, 'en'), '1/9 07:03');
      expect(relTimeLabel(early, 'es'), '9/1 7:03');
      expect(relTimeLabel(early, 'pt'), '9/1 07:03');
    });

    test('a language without date data falls back to M/d HH:mm', () {
      expect(relTimeLabel(t, 'zz'), '11/3 14:05');
    });
  });
}
