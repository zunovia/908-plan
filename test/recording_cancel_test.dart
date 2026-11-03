// Cancelling a recording (× / back) must discard the take: no analysis, no
// Hive record, no voice clip, temp WAV deleted — and the screen must leave
// instead of moving on to the result.
//
// Regression: the × button used to call stopRecording(), which analyzes and
// saves; and when the screen was opened with go('/recording') the pop threw,
// so the screen stayed and showed "received your voice".

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zero_app/core/providers/audio_providers.dart';
import 'package:zero_app/core/providers/storage_providers.dart';
import 'package:zero_app/features/recording/presentation/screens/recording_screen.dart';
import 'package:zero_app/features/recording/presentation/widgets/breathing_dot.dart';
import 'package:zero_app/features/recording/providers/recording_phase_provider.dart';
import 'package:zero_app/features/recording/providers/recording_provider.dart';

import 'fakes/recording_fakes.dart';

class _Harness {
  _Harness({required this.tempDir, bool writeFiles = true})
      : recorder = FakeRecorderService(writeFiles: writeFiles);

  final Directory tempDir;
  final FakeRecorderService recorder;
  final FakeAnalyzer analyzer = FakeAnalyzer();
  final FakeRecordingRepository repo = FakeRecordingRepository();
  final FakeVoiceClipService clips = FakeVoiceClipService();

  List<Override> get overrides => [
        recorderServiceProvider.overrideWithValue(recorder),
        voiceAnalyzerProvider.overrideWithValue(analyzer.analyze),
        localRecordingRepositoryProvider.overrideWithValue(repo),
        voiceClipServiceProvider.overrideWithValue(clips),
        recordingTempDirectoryProvider.overrideWithValue(() async => tempDir),
        soundManagerProvider.overrideWithValue(FakeSoundManager()),
      ];

  void expectNothingKept() {
    expect(analyzer.calls, 0, reason: 'cancel must not analyze');
    expect(repo.saved, isEmpty, reason: 'cancel must not save a record');
    expect(clips.clippedIds, isEmpty, reason: 'cancel must not keep a clip');
  }
}

void main() {
  group('RecordingNotifier.cancelRecording', () {
    late Directory tmp;
    late _Harness h;
    late ProviderContainer c;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('voxna_cancel_test_');
      h = _Harness(tempDir: tmp);
      c = ProviderContainer(overrides: h.overrides);
    });

    tearDown(() {
      c.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    List<File> wavs() => tmp.listSync().whereType<File>().toList();

    test('control: stopRecording analyzes, saves and clips', () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      expect(wavs(), hasLength(1));

      await n.stopRecording();

      expect(h.analyzer.calls, 1);
      expect(h.repo.saved, hasLength(1));
      expect(h.clips.clippedIds, hasLength(1));
      expect(wavs(), isEmpty, reason: 'temp WAV is deleted after analysis');
      expect(c.read(recordingProvider).isFinished, isTrue);
    });

    test('cancel mid-take keeps nothing and deletes the temp WAV', () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(c.read(recordingProvider).elapsed, greaterThan(Duration.zero));
      expect(wavs(), hasLength(1));

      await n.cancelRecording();

      h.expectNothingKept();
      expect(h.recorder.stopCalls, 1, reason: 'the recorder is stopped');
      expect(wavs(), isEmpty, reason: 'temp WAV deleted');
      final s = c.read(recordingProvider);
      expect(s.isRecording, isFalse);
      expect(s.cancelled, isTrue);
      expect(s.isFinished, isFalse);
      expect(s.filePath, isNull);
      expect(s.lastRecordingId, isNull);

      // The elapsed timer is stopped too: nothing auto-finishes later.
      final before = c.read(recordingProvider).elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(c.read(recordingProvider).elapsed, before);
      h.expectNothingKept();
    });

    test('state is reset synchronously, before the recorder stops', () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      final seen = <RecordingState>[];
      c.listen<RecordingState>(recordingProvider, (_, next) => seen.add(next));

      final f = n.cancelRecording();
      // No await yet: a screen listener already sees a cancelled idle state.
      expect(c.read(recordingProvider).cancelled, isTrue);
      expect(c.read(recordingProvider).isRecording, isFalse);
      await f;
      expect(seen.any((s) => s.isFinished), isFalse);
    });

    test('cancel while "done" is still analyzing discards the take', () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      h.analyzer.gate = Completer<void>();

      final stopping = n.stopRecording();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.analyzer.calls, 1, reason: 'analysis has started');

      await n.cancelRecording();
      h.analyzer.gate!.complete();
      await stopping;

      expect(h.repo.saved, isEmpty);
      expect(h.clips.clippedIds, isEmpty);
      expect(wavs(), isEmpty);
      expect(c.read(recordingProvider).isFinished, isFalse);
      expect(c.read(recordingProvider).cancelled, isTrue);
    });

    test('cancel while the recorder is starting stops and discards it',
        () async {
      h.recorder.startGate = Completer<void>();
      final n = c.read(recordingProvider.notifier);
      final starting = n.startRecording();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(h.recorder.startedPaths, hasLength(1));

      await n.cancelRecording();
      h.recorder.startGate!.complete();
      await starting;

      h.expectNothingKept();
      expect(wavs(), isEmpty);
      expect(c.read(recordingProvider).isRecording, isFalse);
      // No elapsed timer was started for the cancelled take.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(c.read(recordingProvider).elapsed, Duration.zero);
    });

    test('stopping flag: set synchronously, cleared at the end, saves once',
        () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      h.analyzer.gate = Completer<void>();

      final first = n.stopRecording();
      // No await yet: the UI already sees "stopping" (cancel is disabled).
      expect(c.read(recordingProvider).isStopping, isTrue);
      expect(c.read(recordingProvider).isRecording, isTrue);
      // A second stop (完了 tapped again / auto-stop) is ignored.
      final second = n.stopRecording();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      h.analyzer.gate!.complete();
      await Future.wait([first, second]);

      expect(h.analyzer.calls, 1);
      expect(h.repo.saved, hasLength(1));
      expect(h.clips.clippedIds, hasLength(1));
      final s = c.read(recordingProvider);
      expect(s.isStopping, isFalse);
      expect(s.isFinished, isTrue);
    });

    test('auto-stop at the duration end also sets the stopping flag',
        () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording(duration: const Duration(milliseconds: 300));
      h.analyzer.gate = Completer<void>();
      final seen = <bool>[];
      c.listen<RecordingState>(
          recordingProvider, (_, next) => seen.add(next.isStopping));

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(c.read(recordingProvider).isStopping, isTrue,
          reason: 'auto-stop is waiting for the analysis');
      h.analyzer.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(seen, contains(true));
      expect(c.read(recordingProvider).isStopping, isFalse);
      expect(h.repo.saved, hasLength(1));
    });

    test('stopping flag is cleared when the recorder returns no file',
        () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      h.recorder.stopReturnsNull = true;
      await n.stopRecording();
      final s = c.read(recordingProvider);
      expect(s.isStopping, isFalse);
      expect(s.isRecording, isFalse);
      expect(h.repo.saved, isEmpty);
    });

    test('a new take after a cancel records normally', () async {
      final n = c.read(recordingProvider.notifier);
      await n.startRecording();
      await n.cancelRecording();

      await n.startRecording();
      expect(c.read(recordingProvider).cancelled, isFalse);
      await n.stopRecording();
      expect(h.repo.saved, hasLength(1));
      expect(c.read(recordingProvider).isFinished, isTrue);
    });
  });

  group('RecordingScreen × / back', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    // Opens the recording screen either with push (home) or with go
    // (onboarding first recording), from a stand-in start page.
    Future<(GoRouter, _Harness, ProviderContainer)> open(
      WidgetTester tester, {
      required bool push,
      List<Override> extraOverrides = const [],
    }) async {
      final h = _Harness(tempDir: Directory('fake_tmp'), writeFiles: false);
      final c =
          ProviderContainer(overrides: [...h.overrides, ...extraOverrides]);
      addTearDown(c.dispose);
      final router = GoRouter(
        initialLocation: push ? '/home' : '/onboarding/first-recording',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/recording'),
                child: const Text('home'),
              ),
            ),
          ),
          GoRoute(
            path: '/onboarding/first-recording',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.go('/recording'),
                child: const Text('first'),
              ),
            ),
          ),
          GoRoute(
            path: '/recording',
            builder: (_, __) => const RecordingScreen(durationSeconds: 30),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(TextButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_top(router), '/recording');
      // Record for "3 seconds".
      await tester.pump(const Duration(seconds: 3));
      expect(c.read(recordingProvider).isRecording, isTrue);
      expect(h.recorder.startedPaths, hasLength(1));
      return (router, h, c);
    }

    Future<void> expectDiscardedAndLeft(
      WidgetTester tester,
      GoRouter router,
      _Harness h,
      ProviderContainer c,
    ) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.takeException(), isNull);
      expect(_top(router), '/home');
      expect(find.byType(RecordingScreen), findsNothing);
      expect(find.byType(BreathingDot), findsNothing);
      expect(find.text('あなたの声を受け取りました'), findsNothing);
      expect(c.read(recordingPhaseProvider), RecordingPhase.recording);
      expect(c.read(recordingProvider).isRecording, isFalse);
      expect(c.read(recordingProvider).cancelled, isTrue);
      expect(h.recorder.stopCalls, 1);
      h.expectNothingKept();
      // Let the screen's own timers finish before the test ends.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('while stopping: × is disabled and back does not cancel',
        (tester) async {
      final (router, h, c) = await open(tester, push: true);
      h.analyzer.gate = Completer<void>();

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(c.read(recordingProvider).isStopping, isTrue);
      expect(h.analyzer.calls, 1, reason: 'the save step has started');

      // × is disabled; tapping it does nothing.
      final close = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.close));
      expect(close.onPressed, isNull);
      await tester.tap(find.byTooltip('キャンセル'), warnIfMissed: false);
      // 完了 is disabled too, so the take cannot be stopped twice.
      final done = tester.widget<ElevatedButton>(
          find.byWidgetPredicate((w) => w is ElevatedButton));
      expect(done.onPressed, isNull);
      // System back is a no-op.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));

      expect(_top(router), '/recording');
      expect(find.byType(RecordingScreen), findsOneWidget);
      expect(c.read(recordingProvider).cancelled, isFalse);
      expect(c.read(recordingProvider).isStopping, isTrue);
      expect(h.recorder.stopCalls, 1, reason: 'only the 完了 stop ran');
      expect(h.analyzer.calls, 1);

      // End the test with the screen gone (the held analysis is abandoned).
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('finishing (完了) still goes to the breathing phase',
        (tester) async {
      final gate = Completer<void>();
      final (_, _, c) = await open(
        tester,
        push: true,
        extraOverrides: [
          recordingProvider.overrideWith(() => _InstantStopNotifier(gate)),
        ],
      );

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      expect(c.read(recordingProvider).isStopping, isTrue);
      expect(c.read(recordingPhaseProvider), RecordingPhase.recording);

      gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.read(recordingProvider).isFinished, isTrue);
      expect(c.read(recordingPhaseProvider), RecordingPhase.breathing);
      expect(find.byType(BreathingDot), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      // The container owns the elapsed timer: dispose it before the check.
      c.dispose();
      await tester.pump(const Duration(seconds: 4));
    });

    for (final push in [true, false]) {
      final how = push ? 'pushed from home' : 'opened with go (onboarding)';

      testWidgets('× discards the take and leaves — $how', (tester) async {
        final (router, h, c) = await open(tester, push: push);
        await tester.tap(find.byTooltip('キャンセル'));
        await expectDiscardedAndLeft(tester, router, h, c);
      });

      testWidgets('system back discards the take and leaves — $how',
          (tester) async {
        final (router, h, c) = await open(tester, push: push);
        await tester.binding.handlePopRoute();
        await expectDiscardedAndLeft(tester, router, h, c);
      });
    }
  });
}

/// The location on top (a pushed route does not change the base uri).
String _top(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

/// A notifier whose stop finishes without file I/O (widget tests cannot
/// await real I/O), mirroring the real state sequence.
class _InstantStopNotifier extends RecordingNotifier {
  _InstantStopNotifier(this.gate);

  final Completer<void> gate;

  @override
  Future<void> stopRecording() async {
    if (!state.isRecording || state.isStopping) return;
    state = state.copyWith(isStopping: true);
    await gate.future;
    state = state.copyWith(
      isRecording: false,
      isStopping: false,
      filePath: 'x.wav',
      lastRecordingId: '1',
    );
  }
}
