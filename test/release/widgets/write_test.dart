import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/release_tools.dart';
import 'package:zero_app/features/release/presentation/release_ui.dart';
import 'package:zero_app/features/release/presentation/screens/crisis_screen.dart';
import 'package:zero_app/features/release/presentation/screens/release_scene_screen.dart';
import 'package:zero_app/features/release/presentation/screens/write_screen.dart';
import 'package:zero_app/features/release/providers/release_providers.dart';

import 'release_widget_harness.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ja'));

  setUpAll(ReleaseHarness.open);
  tearDownAll(ReleaseHarness.close);
  setUp(() async {
    await ReleaseHarness.reset();
    await ReleaseHarness.saveSettings();
  });

  Finder letGoButton() => find.widgetWithText(FilledButton, l10n.rel_write_letgo);

  ReleaseSceneArgs sceneArgs(WidgetTester tester) =>
      tester.widget<ReleaseSceneScreen>(find.byType(ReleaseSceneScreen)).args;

  testWidgets('text + chips + scene go to the release scene with the right args', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.write);
    expect(find.byType(WriteScreen), findsOneWidget);

    // 何も無いうちは主ボタンは押せない。
    expect(tester.widget<FilledButton>(letGoButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, '  返信がないだけで嫌われたと感じた  ');
    await tester.tap(find.widgetWithText(FilterChip, l10n.rel_memory_label_defaults_1)); // 人
    await tester.tap(find.widgetWithText(ChoiceChip, l10n.rel_scene_defaults_4)); // 眠る前
    await tester.pump();

    await tester.tap(letGoButton());
    await ReleaseHarness.settle(tester);

    expect(find.byType(ReleaseSceneScreen), findsOneWidget);
    final args = sceneArgs(tester);
    expect(args.mode, ReleaseMode.WORDS4);
    expect(args.note, '返信がないだけで嫌われたと感じた');
    expect(args.tags, [l10n.rel_memory_label_defaults_1]);
    expect(args.scene, l10n.rel_scene_defaults_4);
    expect(args.keep, isTrue);
    expect(args.meltText, '返信がないだけで嫌われたと感じた');
    expect(args.abuseContext, isFalse);
    expect(args.softCrisis, isFalse);
    // まだ 1 回もタップしていないので何も保存されていない。
    expect(c.read(releaseRepositoryProvider).allSessions(), isEmpty);
  });

  testWidgets('"残さない" drops the note but keeps the melt text', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.write);

    await tester.enterText(find.byType(TextField).first, '言えなかったこと');
    await tester.tap(find.text(l10n.rel_write_no_keep));
    await tester.pump();
    await tester.tap(letGoButton());
    await ReleaseHarness.settle(tester);

    final args = sceneArgs(tester);
    expect(args.keep, isFalse);
    expect(args.note, isNull);
    expect(args.meltText, '言えなかったこと');
  });

  testWidgets('"残さない" also keeps own-typed chips out of the saved tags', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.write);

    await tester.enterText(find.byType(TextField).at(1), '自分で打った言葉');
    await tester.pump();
    await tester.tap(find.text(l10n.rel_write_custom_tag_add));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, l10n.rel_memory_label_defaults_1)); // 人
    await tester.tap(find.text(l10n.rel_write_no_keep));
    await tester.pump();
    await tester.tap(letGoButton());
    await ReleaseHarness.settle(tester);

    final args = sceneArgs(tester);
    expect(args.keep, isFalse);
    expect(args.tags, [l10n.rel_memory_label_defaults_1]);
    expect(args.tags, isNot(contains('自分で打った言葉')));
    // 溶ける演出には自分のチップも出す（保存はしない）。
    expect(args.meltText, contains('自分で打った言葉'));
  });

  testWidgets('"何もなくても" goes to the scene with nothing to save', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.write);

    await tester.tap(find.text(l10n.rel_write_letgo_empty));
    await ReleaseHarness.settle(tester);
    final args = sceneArgs(tester);
    expect(args.note, isNull);
    expect(args.tags, isEmpty);
    expect(args.meltText, isNull);
  });

  testWidgets('from a recording: voice tendency chips are pre-selected and stored as voice:* tags', (tester) async {
    final c = ReleaseHarness.container(voiceTags: {
      'rec1': const ['voice:low_energy', 'voice:fast_tempo'],
    });
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.writeWith(voice: 'rec1'));

    expect(find.text(l10n.rel_vx_write_from_voice), findsOneWidget);
    final low = find.widgetWithText(FilterChip, l10n.rel_vx_voice_low_energy);
    expect(low, findsOneWidget);
    expect(tester.widget<FilterChip>(low).selected, isTrue);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, l10n.rel_vx_voice_fast_tempo)).selected, isTrue);

    // 1 つ外す。チップだけでも主ボタンは押せる。
    await tester.tap(find.widgetWithText(FilterChip, l10n.rel_vx_voice_fast_tempo));
    await tester.pump();
    await tester.tap(letGoButton());
    await ReleaseHarness.settle(tester);

    final args = sceneArgs(tester);
    expect(args.tags, ['voice:low_energy']);
    expect(args.voiceRecordingId, 'rec1');
    expect(args.meltText, l10n.rel_vx_voice_low_energy);

    // 最初のタップでセッションができ、声の録音と傾向タグが残る。
    await tester.tap(find.byType(ReleaseSceneScreen));
    await ReleaseHarness.settle(tester);
    final sessions = c.read(releaseRepositoryProvider).allSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.voiceRecordingId, 'rec1');
    expect(sessions.single.memoryTags, ['voice:low_energy']);
  });

  testWidgets('crisis text is not saved and opens the helpline screen', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.write);

    await tester.enterText(find.byType(TextField).first, 'もう死にたい');
    await tester.pump();
    await tester.tap(letGoButton());
    await ReleaseHarness.settle(tester);

    expect(find.byType(CrisisScreen), findsOneWidget);
    expect(find.byType(ReleaseSceneScreen), findsNothing);
    expect(find.text(l10n.rel_crisis_headline), findsOneWidget);
    expect(find.text(l10n.rel_vx_write_crisis_not_saved), findsOneWidget);

    final sessions = c.read(releaseRepositoryProvider).allSessions();
    // 危機の印だけ（本文・チップなし）。
    expect(sessions, hasLength(1));
    expect(sessions.single.crisis, isTrue);
    expect(sessions.single.note, isNull);
    expect(sessions.single.memoryTags, isEmpty);
    for (final raw in ReleaseHarness.db.sessions.values) {
      expect(raw.toString(), isNot(contains('死にたい')));
    }
    expect(ReleaseHarness.db.turns.isEmpty, isTrue);
    expect(c.read(releaseSettingsProvider).lastCrisisAt, greaterThan(0));
  });

  testWidgets('a crisis phrase typed as an own chip is also caught', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.write);

    await tester.enterText(find.byType(TextField).at(1), '死にたい');
    await tester.pump();
    await tester.tap(find.text(l10n.rel_write_custom_tag_add));
    await tester.pump();
    await tester.tap(letGoButton());
    await ReleaseHarness.settle(tester);

    expect(find.byType(CrisisScreen), findsOneWidget);
    expect(c.read(releaseRepositoryProvider).allSessions().every((s) => s.crisis), isTrue);
  });
}
