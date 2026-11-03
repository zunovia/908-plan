import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/release_tools.dart';
import 'package:zero_app/features/release/presentation/release_ui.dart';
import 'package:zero_app/features/release/presentation/screens/done_screen.dart';
import 'package:zero_app/features/release/presentation/screens/release_home_screen.dart';
import 'package:zero_app/features/release/presentation/screens/release_scene_screen.dart';
import 'package:zero_app/features/release/presentation/widgets/word_repeater.dart';
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

  Future<GoRouter> openScene(WidgetTester tester, ProviderContainer c, ReleaseSceneArgs args) async {
    final router = await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.home);
    router.push(ReleasePaths.scene, extra: args);
    await ReleaseHarness.settle(tester);
    expect(find.byType(ReleaseSceneScreen), findsOneWidget);
    return router;
  }

  Future<void> tapWord(WidgetTester tester) async {
    await tester.tap(find.byType(WordRepeater));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('first tap creates the session, taps count up and cycle the words', (tester) async {
    final tts = FakeTts();
    await ReleaseHarness.saveSettings(tts: true);
    final c = ReleaseHarness.container(tts: tts);
    addTearDown(c.dispose);
    await openScene(
      tester,
      c,
      const ReleaseSceneArgs(note: '書いたこと', tags: ['仕事'], meltText: '書いたこと', scene: '会う前'),
    );
    final repo = c.read(releaseRepositoryProvider);

    expect(find.text('0 / 27'), findsOneWidget);
    expect(repo.allSessions(), isEmpty);
    // 書いた文字（溶ける演出）と自分への一文。
    expect(find.bySemanticsLabel('書いたこと'), findsOneWidget);

    final first = tester.widget<WordRepeater>(find.byType(WordRepeater)).word;
    await tapWord(tester);
    await ReleaseHarness.settle(tester, frames: 2);
    expect(find.text('1 / 27'), findsOneWidget);
    final sessions = repo.allSessions();
    expect(sessions, hasLength(1));
    expect(sessions.single.kind, SessionKind.WORDS4);
    expect(sessions.single.note, '書いたこと');
    expect(sessions.single.memoryTags, ['仕事']);
    expect(sessions.single.scene, '会う前');
    expect(sessions.single.isCompleted, isFalse);
    expect(tts.spoken, [first]);

    final second = tester.widget<WordRepeater>(find.byType(WordRepeater)).word;
    expect(second, isNot(first));
    await tapWord(tester);
    expect(find.text('2 / 27'), findsOneWidget);
    expect(repo.allSessions(), hasLength(1));

    // 終える → 完了画面。今月 1 回目。
    await tester.tap(find.widgetWithText(FilledButton, l10n.rel_cleaning_end));
    await ReleaseHarness.settle(tester);
    expect(find.byType(DoneScreen), findsOneWidget);
    expect(find.text(l10n.rel_done_released), findsOneWidget);
    expect(find.text(l10n.rel_done_nth(1)), findsOneWidget);
    final done = repo.allSessions().single;
    expect(done.isCompleted, isTrue);
    expect(done.count, 2);
  });

  testWidgets('leaving without a tap saves nothing', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await openScene(tester, c, const ReleaseSceneArgs());
    await tester.tap(find.widgetWithText(FilledButton, l10n.rel_cleaning_end));
    await ReleaseHarness.settle(tester);
    expect(find.byType(ReleaseSceneScreen), findsNothing);
    expect(find.byType(ReleaseHomeScreen), findsOneWidget);
    expect(c.read(releaseRepositoryProvider).allSessions(), isEmpty);
  });

  testWidgets('goal options and own tools (add / delete) work', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await openScene(tester, c, const ReleaseSceneArgs());

    await tester.tap(find.byTooltip(l10n.rel_release_settings));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '108'));
    await tester.pump();
    expect(find.text('0 / 108'), findsOneWidget);

    // ツール選択 → 自分でつくる。
    await tester.tap(find.textContaining(l10n.rel_cleaning_tool_set));
    await ReleaseHarness.settle(tester, frames: 4);
    expect(find.text(l10n.rel_cleaning_tool_dialog_title), findsOneWidget);
    await tester.tap(find.text(l10n.rel_cleaning_tool_create));
    await ReleaseHarness.settle(tester, frames: 4);
    await tester.enterText(find.byType(TextField), 'Delete キーを押す');
    await tester.pump();
    await tester.tap(find.text(l10n.rel_cleaning_tool_create_save));
    await ReleaseHarness.settle(tester, frames: 6);

    expect(tester.widget<WordRepeater>(find.byType(WordRepeater)).word, 'Delete キーを押す');
    expect(c.read(releaseSettingsProvider).ownTools, ['Delete キーを押す']);
    expect(c.read(releaseSettingsProvider).releaseTool, ReleaseTools.ownId('Delete キーを押す'));

    // 消すと、いつもの組に戻る。
    await tester.tap(find.textContaining('Delete キーを押す').first);
    await ReleaseHarness.settle(tester, frames: 4);
    await tester.tap(find.byTooltip(l10n.rel_cleaning_tool_delete('Delete キーを押す')));
    await ReleaseHarness.settle(tester, frames: 4);
    await tester.tap(find.text(l10n.rel_cleaning_tool_close));
    await ReleaseHarness.settle(tester, frames: 4);
    expect(c.read(releaseSettingsProvider).ownTools, isEmpty);
    expect(c.read(releaseSettingsProvider).releaseTool, ReleaseTools.set);
  });

  testWidgets('a crisis phrase as an own tool is not saved and opens the helplines', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    await openScene(tester, c, const ReleaseSceneArgs());

    await tester.tap(find.textContaining(l10n.rel_cleaning_tool_set));
    await ReleaseHarness.settle(tester, frames: 4);
    await tester.tap(find.text(l10n.rel_cleaning_tool_create));
    await ReleaseHarness.settle(tester, frames: 4);
    await tester.enterText(find.byType(TextField), 'もう死にたい');
    await tester.pump();
    await tester.tap(find.text(l10n.rel_cleaning_tool_create_save));
    await ReleaseHarness.settle(tester, frames: 8);

    expect(c.read(releaseSettingsProvider).ownTools, isEmpty);
    expect(find.text(l10n.rel_crisis_headline), findsOneWidget);
    final sessions = c.read(releaseRepositoryProvider).allSessions();
    expect(sessions.where((s) => s.crisis), hasLength(1));
    expect(sessions.every((s) => s.note == null), isTrue);
  });

  testWidgets('quick: 3 taps then automatically to done', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    final router = await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.home);
    router.push(ReleasePaths.quick);
    await ReleaseHarness.settle(tester, frames: 4);
    final scene = tester.widget<ReleaseSceneScreen>(find.byType(ReleaseSceneScreen));
    expect(scene.args.quick, isTrue);
    expect(find.text(l10n.rel_release_quick_hint), findsOneWidget);

    // ひと言は自動ループ（ふつう 1.6 秒）でも進むが、ここでは手で 3 回。
    await tapWord(tester);
    await tapWord(tester);
    await tapWord(tester);
    expect(find.text('3 / 3'), findsOneWidget);
    await pumpFor(tester, const Duration(milliseconds: 1200));
    await ReleaseHarness.settle(tester);
    expect(find.byType(DoneScreen), findsOneWidget);
    final s = c.read(releaseRepositoryProvider).allSessions().single;
    expect(s.kind, SessionKind.WORDS1);
    expect(s.trigger, SessionTrigger.QUICK);
    expect(s.count, 3);
    expect(s.isCompleted, isTrue);
  });

  testWidgets('done: milestone text, mood, and close back to the tab', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    final repo = c.read(releaseRepositoryProvider);
    String last = '';
    for (var i = 0; i < 7; i++) {
      last = await repo.startSession(kind: SessionKind.WORDS4);
      await repo.finishSession(last, 3);
    }
    final router = await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.home);
    router.go(ReleasePaths.doneFor(last));
    await ReleaseHarness.settle(tester);

    expect(find.text(l10n.rel_done_milestone(7)), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l10n.rel_mood_content_description(4)));
    await ReleaseHarness.settle(tester, frames: 2);
    expect(repo.sessionById(last)!.moodAfter, 4);

    await tester.tap(find.text(l10n.rel_done_close));
    await ReleaseHarness.settle(tester);
    expect(find.byType(ReleaseHomeScreen), findsOneWidget);
    expect(find.text(l10n.rel_home_month_count(7)), findsOneWidget);
  });

  testWidgets('with animations on: text melts and the breathing ring runs without errors', (tester) async {
    final c = ReleaseHarness.container();
    addTearDown(c.dispose);
    final router = await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.home, reduceMotion: false);
    router.push(
      ReleasePaths.scene,
      extra: const ReleaseSceneArgs(note: 'にじんで消える', meltText: 'にじんで消える'),
    );
    await pumpFor(tester, const Duration(seconds: 6));
    expect(find.byType(ReleaseSceneScreen), findsOneWidget);
    expect(find.byType(ScaleTransition), findsWidgets);
    await tapWord(tester);
    expect(find.text('1 / 27'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
