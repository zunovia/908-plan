import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zero_app/features/recording/presentation/widgets/self_assessment_chips.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Same frame as RecordingScreen: Scaffold → SafeArea → the phase widget
  // (Scaffold gives its body a loose width, which is what pushed the block
  // to the left before).
  Future<AppLocalizations> pump(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SelfAssessmentChips(onSelected: (_) {}, onSkip: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    return lookupAppLocalizations(const Locale('ja'));
  }

  testWidgets('the question, the chips and スキップ are centred horizontally', (tester) async {
    final l10n = await pump(tester);
    final centerX = tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;

    expect(tester.getCenter(find.text(l10n.assessment_question)).dx,
        moreOrLessEquals(centerX, epsilon: 1));
    expect(tester.getCenter(find.byType(Wrap)).dx, moreOrLessEquals(centerX, epsilon: 1));
    expect(tester.getCenter(find.text(l10n.common_skip)).dx, moreOrLessEquals(centerX, epsilon: 1));

    // The chips as a group are centred too (left and right gaps match).
    final chips = find.byType(ActionChip);
    expect(chips, findsNWidgets(4));
    final rects = [for (final e in chips.evaluate()) tester.getRect(find.byWidget(e.widget))];
    final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
    final right = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);
    expect((left + right) / 2, moreOrLessEquals(centerX, epsilon: 1));
  });

  testWidgets('the block is centred vertically as before', (tester) async {
    final l10n = await pump(tester);
    final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final top = tester.getTopLeft(find.text(l10n.assessment_question)).dy;
    final bottom = tester.getBottomLeft(find.text(l10n.common_skip)).dy;
    expect((top + bottom) / 2, moreOrLessEquals(screenH / 2, epsilon: 24));
  });

  testWidgets('a large text scale does not overflow and everything stays reachable', (tester) async {
    final l10n = await pump(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(l10n.common_skip));
    await tester.tap(find.text(l10n.common_skip));
  });
}
