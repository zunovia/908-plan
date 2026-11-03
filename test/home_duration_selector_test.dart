import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zero_app/features/home/presentation/widgets/duration_selector.dart';

/// Pixel 6a: 1080 x 2400 px at 2.625 → about 411 x 914 dp.
const Size pixel6aPhysical = Size(1080, 2400);
const double pixel6aRatio = 2.625;

/// The test font draws every glyph 1em wide, which makes Latin labels far
/// wider than on a phone. Load Roboto from the Flutter SDK under the family
/// the labels use, so Latin text gets real proportional widths (CJK glyphs
/// are not in Roboto and keep the 1em test glyphs, which matches full-width
/// kana / kanji). Returns false when the SDK font cannot be found.
Future<bool> loadRealLatinMetrics(String family) async {
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final font = File('${artifacts.path}/material_fonts/roboto-regular.ttf');
  if (!font.existsSync()) return false;
  final bytes = font.readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
  return true;
}

void main() {
  bool? realMetrics;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required String lang,
    required RecordingDuration selected,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = pixel6aPhysical;
    tester.view.devicePixelRatio = pixel6aRatio;
    addTearDown(tester.view.reset);
    final app = MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      // Same frame as the home screen: 24dp side padding in a scroll view.
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                DurationSelector(selected: selected, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app);
    final l10n = lookupAppLocalizations(Locale(lang));
    if (realMetrics == null) {
      final family = tester.widget<Text>(find.text(l10n.duration_short)).style?.fontFamily;
      realMetrics =
          family != null && (await tester.runAsync(() => loadRealLatinMetrics(family)) ?? false);
      // Lay the text out again with the newly registered font.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app);
    }
    await tester.pump();
    return l10n;
  }

  List<String> labels(AppLocalizations l10n) =>
      [for (final d in RecordingDuration.values) d.label(l10n)];

  /// Every label is drawn whole: not clipped by the chip and not shrunk.
  void expectFullLabels(WidgetTester tester, AppLocalizations l10n, {bool allowShrink = false}) {
    for (final label in labels(l10n)) {
      final text = find.text(label);
      expect(text, findsOneWidget, reason: label);
      final paragraph = tester.renderObject<RenderBox>(text);
      final box = find.ancestor(of: text, matching: find.byType(FittedBox));
      final shown = tester.getSize(box);
      if (!allowShrink) {
        expect(shown.width, moreOrLessEquals(paragraph.size.width, epsilon: 0.01), reason: label);
      }
      // The chip is never narrower than what it shows.
      final chip = find.ancestor(of: text, matching: find.byType(ChoiceChip));
      expect(tester.getSize(chip).width, greaterThanOrEqualTo(shown.width), reason: label);
    }
  }

  void expectInsideScreen(WidgetTester tester) {
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      final rect = tester.getRect(find.byWidget(chip));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
    }
  }

  Set<double> rows(WidgetTester tester) => {
        for (final e in find.byType(ChoiceChip).evaluate())
          tester.getRect(find.byWidget(e.widget)).top
      };

  for (final lang in ['ja', 'en', 'es', 'pt']) {
    for (final selected in RecordingDuration.values) {
      testWidgets('$lang, ${selected.name} selected: all three labels fit in one row at 1080px',
          (tester) async {
        final l10n = await pump(tester, lang: lang, selected: selected);
        expect(tester.takeException(), isNull);
        expectFullLabels(tester, l10n);
        expectInsideScreen(tester);
        if (lang == 'ja' || realMetrics == true) {
          expect(rows(tester), hasLength(1), reason: labels(l10n).join(' / '));
        }
      });
    }

    testWidgets('$lang at 1.3x text: labels stay whole (wrap instead of being cut)',
        (tester) async {
      final l10n =
          await pump(tester, lang: lang, selected: RecordingDuration.normal30, textScale: 1.3);
      expect(tester.takeException(), isNull);
      expectFullLabels(tester, l10n);
      expectInsideScreen(tester);
      // With real Latin metrics the chips wrap to at most two rows. Without
      // them (CI: no SDK font, 1em test glyphs) Latin labels are much wider,
      // so only require that they wrap rather than get cut.
      final maxRows = (lang == 'ja' || realMetrics == true) ? 2 : 3;
      expect(rows(tester).length, lessThanOrEqualTo(maxRows));
    });
  }

  testWidgets('selecting does not change the chip width (no checkmark)', (tester) async {
    await pump(tester, lang: 'ja', selected: RecordingDuration.short15);
    final l10n = lookupAppLocalizations(const Locale('ja'));
    final chip =
        find.ancestor(of: find.text(l10n.duration_normal), matching: find.byType(ChoiceChip));
    final before = tester.getSize(chip).width;
    expect(tester.widget<ChoiceChip>(chip).showCheckmark, isFalse);
    await pump(tester, lang: 'ja', selected: RecordingDuration.normal30);
    expect(tester.getSize(chip).width, before);
  });

  testWidgets('an extreme text scale shrinks a label instead of clipping it', (tester) async {
    final l10n =
        await pump(tester, lang: 'ja', selected: RecordingDuration.normal30, textScale: 3.5);
    expect(tester.takeException(), isNull);
    expectFullLabels(tester, l10n, allowShrink: true);
    expectInsideScreen(tester);
  });
}
