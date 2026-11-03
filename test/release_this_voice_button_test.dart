import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zero_app/features/recording/presentation/widgets/mini_insight_card.dart';
import 'package:zero_app/features/release/presentation/release_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<AppLocalizations> pump(WidgetTester tester, List<String> tags) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [releaseVoiceTagsProvider.overrideWith((ref, id) => tags)],
        child: const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReleaseThisVoiceButton(recordingId: 'r1')),
        ),
      ),
    );
    await tester.pump();
    return lookupAppLocalizations(const Locale('ja'));
  }

  testWidgets('the pre-selection hint shows only when there is a voice tendency', (tester) async {
    final l10n = await pump(tester, const ['voice:low_energy']);
    expect(find.text(l10n.rel_vx_release_this_voice), findsOneWidget);
    expect(find.text(l10n.rel_vx_release_this_voice_hint), findsOneWidget);
  });

  testWidgets('first recordings (no baseline yet) keep the button but drop the hint', (tester) async {
    final l10n = await pump(tester, const []);
    expect(find.text(l10n.rel_vx_release_this_voice), findsOneWidget);
    expect(find.text(l10n.rel_vx_release_this_voice_hint), findsNothing);
  });
}
