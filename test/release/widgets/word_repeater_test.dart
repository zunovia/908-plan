import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/presentation/widgets/rel_styles.dart';
import 'package:zero_app/features/release/presentation/widgets/word_repeater.dart';

import 'release_widget_harness.dart';

void main() {
  setUpAll(() => RelStyles.plainFonts = true);

  Future<void> pump(
    WidgetTester tester, {
    required String word,
    double textScale = 1.0,
    double width = 1080 / 2.625,
    bool reduceMotion = true,
  }) async {
    tester.view.physicalSize = Size(width * 2.625, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ReleaseHarness.theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        // Same frame as the scene: side padding, centred, in a scroll view.
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: WordRepeater(
                word: word,
                count: 3,
                goal: 27,
                currentWordLabel: 'word',
                remainingLabel: 'left',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Size ringSize(WidgetTester tester) => tester.getSize(
        find.descendant(of: find.byType(WordRepeater), matching: find.byType(CustomPaint)).first,
      );

  RenderParagraph word(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text));

  group('WordRepeater.ringSizeFor', () {
    test('default text size keeps the 210 ring', () {
      expect(WordRepeater.ringSizeFor(textScale: 1.0, maxWidth: 363), 210);
      expect(WordRepeater.ringSizeFor(textScale: 0.85, maxWidth: 363), 210);
    });

    test('grows with the text scale, capped by the available width (and the breath)', () {
      expect(WordRepeater.ringSizeFor(textScale: 1.3, maxWidth: 363), closeTo(273, 0.01));
      expect(WordRepeater.ringSizeFor(textScale: 2.0, maxWidth: 363), closeTo(363 / 1.08, 0.01));
      expect(WordRepeater.ringSizeFor(textScale: 1.0, maxWidth: 150), closeTo(150 / 1.08, 0.01));
      expect(WordRepeater.ringSizeFor(textScale: 2.0, maxWidth: double.infinity), 420);
    });
  });

  testWidgets('default scale: same 210 ring as before', (tester) async {
    await pump(tester, word: 'ありがとう');
    expect(tester.takeException(), isNull);
    expect(ringSize(tester), const Size(210, 210));
    expect(word(tester, 'ありがとう').didExceedMaxLines, isFalse);
  });

  for (final w in ['Delete キーを押す', 'Gracias, te quiero mucho', 'ごめんなさい許してください']) {
    testWidgets('2x text: "$w" fits inside a larger ring without being cut', (tester) async {
      await pump(tester, word: w, textScale: 2.0);
      expect(tester.takeException(), isNull);
      const available = 1080 / 2.625 - 48;
      final ring = ringSize(tester).width;
      expect(ring, greaterThan(210));
      expect(ring, lessThanOrEqualTo(available));
      final p = word(tester, w);
      expect(p.didExceedMaxLines, isFalse);
      // The word stays inside the ring's inner box.
      final box = ring - 2 * WordRepeater.ringPadding;
      expect(p.size.width, lessThanOrEqualTo(box + 0.01));
      expect(p.size.height, lessThanOrEqualTo(box + 0.01));
    });
  }

  testWidgets('a narrow screen at 2x: no overflow, the ring shrinks to fit', (tester) async {
    await pump(tester, word: 'Gracias, te quiero mucho', textScale: 2.0, width: 260);
    expect(tester.takeException(), isNull);
    expect(ringSize(tester).width, lessThanOrEqualTo(260 - 48));
  });

  testWidgets('with the breathing animation running there is no overflow', (tester) async {
    await pump(tester, word: 'Delete キーを押す', textScale: 2.0, reduceMotion: false);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
