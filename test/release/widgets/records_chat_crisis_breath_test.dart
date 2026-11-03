import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/presentation/release_ui.dart';
import 'package:zero_app/features/release/presentation/screens/breath_screen.dart';
import 'package:zero_app/features/release/presentation/screens/chat_screen.dart';
import 'package:zero_app/features/release/presentation/screens/crisis_screen.dart';
import 'package:zero_app/features/release/presentation/screens/done_screen.dart';
import 'package:zero_app/features/release/presentation/screens/write_screen.dart';
import 'package:zero_app/features/release/presentation/widgets/chat_bubbles.dart';
import 'package:zero_app/features/release/presentation/widgets/rel_styles.dart';
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

  Future<String> seedRecord(ProviderContainer c, String note, List<String> tags) async {
    final repo = c.read(releaseRepositoryProvider);
    final id = await repo.startSession(kind: SessionKind.WORDS4, note: note, tags: tags);
    await repo.finishSession(id, 27);
    return id;
  }

  group('records', () {
    testWidgets('filter by chip, long-press delete with confirm', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await seedRecord(c, '仕事のこと', ['仕事']);
      await seedRecord(c, '家族のこと', ['人']);
      await seedRecord(c, '声のこと', ['voice:low_energy']);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.records);

      expect(find.text('仕事のこと'), findsOneWidget);
      expect(find.text('家族のこと'), findsOneWidget);
      // 声の傾向タグは表示名で。
      expect(find.widgetWithText(ChoiceChip, l10n.rel_vx_voice_low_energy), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '仕事'));
      await tester.pump();
      expect(find.text('仕事のこと'), findsOneWidget);
      expect(find.text('家族のこと'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, l10n.rel_records_filter_all));
      await tester.pump();
      await tester.longPress(find.text('家族のこと'));
      await ReleaseHarness.settle(tester, frames: 4);
      expect(find.text(l10n.rel_records_delete_title), findsOneWidget);
      await tester.tap(find.text(l10n.rel_records_delete));
      await ReleaseHarness.settle(tester);
      expect(find.text('家族のこと'), findsNothing);
      expect(c.read(releaseRepositoryProvider).records(), hasLength(2));
    });

    testWidgets('"もう一度手放す" opens write prefilled from the record (sourceSessionId)', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      final id = await seedRecord(c, '同じ記憶', ['過去']);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.records);

      await tester.tap(find.widgetWithText(OutlinedButton, l10n.rel_records_again));
      await ReleaseHarness.settle(tester);
      final write = tester.widget<WriteScreen>(find.byType(WriteScreen));
      expect(write.sourceSessionId, id);
      expect(find.text(l10n.rel_write_from_record), findsOneWidget);
      expect(find.text('同じ記憶'), findsOneWidget);
      final chip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, '過去'));
      expect(chip.selected, isTrue);
    });
  });

  group('chat', () {
    testWidgets('emotion chip gives on-device replies; no AI label', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.chat);
      expect(find.text(l10n.rel_vx_intro_on_device), findsOneWidget);
      expect(find.text('AI'), findsNothing);

      await tester.tap(find.widgetWithText(ActionChip, l10n.rel_emotion_anxiety));
      await ReleaseHarness.settle(tester);
      expect(find.byType(UserBubble), findsOneWidget);
      expect(find.byType(ReplyBubble), findsWidgets);
      expect(c.read(dialogueRepositoryProvider).turns(), hasLength(1));
    });

    testWidgets('crisis text goes to the helpline screen and is not stored', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.chat);

      await tester.enterText(find.byType(TextField), '自殺したいと思う');
      await tester.tap(find.text(l10n.rel_chat_send));
      await ReleaseHarness.settle(tester);
      expect(find.byType(CrisisScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(c.read(dialogueRepositoryProvider).turns(), isEmpty);
      final sessions = c.read(releaseRepositoryProvider).allSessions();
      expect(sessions.single.crisis, isTrue);
    });
  });

  group('crisis', () {
    testWidgets('JP lines with copy; abuse=1 puts ABUSE lines first', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.crisisWith(abuse: true));
      expect(find.text(l10n.rel_crisis_headline), findsOneWidget);
      // ja のアプリ言語で端末の国が取れないときは JP（テスト環境のロケールは en_US の場合がある）。
      final jp = find.widgetWithText(ChoiceChip, 'JP');
      if (tester.widget<ChoiceChip>(jp).selected != true) {
        await tester.tap(jp);
        await tester.pump();
      }
      final numbers = tester.widgetList<SelectableText>(find.byType(SelectableText)).map((t) => t.data).toList();
      // 先頭は DV 相談（ABUSE）。
      expect(numbers.first, '0120-279-889');
      expect(numbers, contains('0120-061-338'));
      expect(find.text('https://findahelpline.com/'), findsOneWidget);
      expect(find.text(l10n.rel_crisis_back_to_app), findsOneWidget);
      expect(c.read(releaseSettingsProvider).lastCrisisAt, greaterThan(0));
    });

    testWidgets('OTHER shows the emergency note and the fallback URL', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.crisis);
      await tester.tap(find.widgetWithText(ChoiceChip, l10n.rel_crisis_country_other));
      await tester.pump();
      expect(find.text(l10n.rel_crisis_emergency_note), findsOneWidget);
      expect(find.text('https://findahelpline.com/'), findsOneWidget);
    });

    Future<void> pumpCrisis(WidgetTester tester, ProviderContainer c, HelplineLauncher launcher) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: ReleaseHarness.theme,
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CrisisScreen(systemCountry: 'JP', launcher: launcher),
          ),
        ),
      );
      await ReleaseHarness.settle(tester);
    }

    testWidgets('call / SMS / fallback URL open external apps', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      final opened = <Uri>[];
      await pumpCrisis(tester, c, (uri) async {
        opened.add(uri);
        return true;
      });
      await tester.tap(find.byTooltip('${l10n.rel_crisis_call} 0120-061-338'));
      await tester.tap(find.byTooltip('${l10n.rel_crisis_call} #8008'));
      await tester.tap(find.text('https://findahelpline.com/'));
      await tester.pump();
      expect(opened[0].toString(), 'tel:0120-061-338');
      expect(opened[1].scheme, 'tel');
      expect(Uri.decodeComponent(opened[1].path), '#8008');
      expect(opened[2].toString(), 'https://findahelpline.com/');
      expect(find.text(l10n.rel_crisis_copied), findsNothing);
    });

    testWidgets('when no app can open the number, it is copied instead', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpCrisis(tester, c, (uri) async => false);
      await tester.tap(find.byTooltip('${l10n.rel_crisis_call} 0120-061-338'));
      await ReleaseHarness.settle(tester, frames: 4);
      expect(clipboard, '0120-061-338');
      expect(find.text(l10n.rel_crisis_copied), findsOneWidget);
    });

    test('SMS URIs drop spaces', () {
      expect(helplineSmsUri('85 258').toString(), 'sms:85258');
      expect(helplineTelUri('116 123').toString(), 'tel:116123');
    });
  });

  group('breath', () {
    testWidgets('one 4-4-8 cycle is saved as a BREATH session', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.breath);
      expect(find.byType(BreathScreen), findsOneWidget);
      expect(find.text('${l10n.rel_breath_phase_in} 4 ／ ${l10n.rel_breath_phase_hold} 4 ／ ${l10n.rel_breath_phase_out} 8'),
          findsOneWidget);

      await tester.tap(find.text(l10n.rel_breath_start));
      for (var i = 0; i < 17; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text(l10n.rel_breath_cycles_label(1)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, l10n.rel_breath_finish));
      await ReleaseHarness.settle(tester);
      expect(find.byType(DoneScreen), findsOneWidget);
      final s = c.read(releaseRepositoryProvider).allSessions().single;
      expect(s.kind, SessionKind.BREATH);
      expect(s.count, 1);
    });

    testWidgets('finishing before one cycle saves nothing', (tester) async {
      final c = ReleaseHarness.container();
      addTearDown(c.dispose);
      await ReleaseHarness.pump(tester, c, initialLocation: ReleasePaths.breath);
      await tester.tap(find.text(l10n.rel_breath_start));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.widgetWithText(FilledButton, l10n.rel_breath_finish));
      await ReleaseHarness.settle(tester);
      expect(find.byType(BreathScreen), findsNothing);
      expect(c.read(releaseRepositoryProvider).allSessions(), isEmpty);
    });
  });

  test('plain fonts are on in widget tests', () => expect(RelStyles.plainFonts, isTrue));
}
