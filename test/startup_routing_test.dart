// Startup routing (splash → onboarding / home) with the real app router.
//
// Regression for the Pixel 6a report (Play 1.2.0+12, fresh install / after
// account deletion): the router used to `watch` auth and onboarding, so the
// anonymous sign-in rebuilt the whole GoRouter, disposed the splash in the
// middle of its startup ("Cannot use ref after the widget was disposed") and,
// when the sign-in had not arrived by the end of the intro (IPv6 black hole:
// it took ~8 minutes on the device), the redirect sent the user back to the
// splash, which kept the intro's last white frame forever.
//
// Local-first now: no screen needs a Firebase user; the sign-in runs in the
// background and its arrival never moves the user or rebuilds the router.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zero_app/app.dart';
import 'package:zero_app/core/audio/sound_manager.dart';
import 'package:zero_app/core/providers/audio_providers.dart';
import 'package:zero_app/core/providers/auth_provider.dart';
import 'package:zero_app/features/home/presentation/screens/home_screen.dart';
import 'package:zero_app/features/home/providers/home_provider.dart';
import 'package:zero_app/features/onboarding/presentation/screens/philosophy_screen.dart';
import 'package:zero_app/features/onboarding/presentation/screens/splash_screen.dart';
import 'package:zero_app/features/onboarding/providers/onboarding_provider.dart';

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

/// Never touched: the fakes override everything the app uses.
class _NoFirebase implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnsupportedError('FirebaseAuth is not used in this test');
}

/// Firebase auth stand-in: `currentUser` plus an auth-state stream that, like
/// `authStateChanges()`, starts with the current user.
class _FakeAuth extends AuthService {
  _FakeAuth({User? user}) : _user = user, super(_NoFirebase()) {
    _changes.add(user);
  }

  final StreamController<User?> _changes = StreamController<User?>();
  User? _user;
  int signInCalls = 0;

  /// When set, sign-in waits for it (a slow or hung network).
  Completer<void>? gate;

  Stream<User?> get changes => _changes.stream;

  @override
  User? get currentUser => _user;

  void emit(User? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    signInCalls++;
    final g = gate;
    if (g != null) await g.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_user == null) emit(_MockUser());
    return _MockCredential();
  }

  Future<void> close() => _changes.close();
}

class _FailingAuth extends AuthService {
  _FailingAuth() : super(_NoFirebase());

  int calls = 0;

  @override
  User? get currentUser => null;

  @override
  Future<UserCredential> signInAnonymously() async {
    calls++;
    throw FirebaseAuthException(code: 'network-request-failed');
  }
}

class _FakeOnboarding extends OnboardingNotifier {
  _FakeOnboarding(this.initial);

  final bool initial;

  @override
  Future<bool> build() async => initial;

  void set(bool done) => state = AsyncData(done);
}

class _EmptyHome extends HomeNotifier {
  @override
  HomeState build() => const HomeState();
}

class _App {
  _App(this.container, this.auth);

  final ProviderContainer container;
  final _FakeAuth auth;

  GoRouter get router => container.read(routerProvider);

  String get path => router.routerDelegate.currentConfiguration.uri.path;

  User? get user => container.read(authStateProvider).valueOrNull;

  _FakeOnboarding get onboarding =>
      container.read(onboardingCompleteProvider.notifier) as _FakeOnboarding;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<_App> pumpApp(
    WidgetTester tester, {
    User? user,
    bool onboardingDone = false,
    bool holdSignIn = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    final auth = _FakeAuth(user: user);
    if (holdSignIn) auth.gate = Completer<void>();
    final c = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(auth),
      authStateProvider.overrideWith((ref) => auth.changes),
      onboardingCompleteProvider
          .overrideWith(() => _FakeOnboarding(onboardingDone)),
      soundManagerProvider.overrideWithValue(SoundManager()..enabled = false),
      homeProvider.overrideWith(_EmptyHome.new),
    ]);
    addTearDown(c.dispose);
    // Not awaited: `done` only arrives while someone listens.
    addTearDown(() => unawaited(auth.close()));
    // In the app the settings listen to the auth state all the time.
    final authSub = c.listen(authStateProvider, (_, __) {});
    addTearDown(authSub.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        // Watches the router like ZeroApp does.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: ref.watch(routerProvider),
          ),
        ),
      ),
    );
    return _App(c, auth);
  }

  /// Advances fake time in steps (every step is one frame).
  Future<void> advance(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 500);
    var left = total;
    while (left > Duration.zero) {
      final d = left < step ? left : step;
      await tester.pump(d);
      left -= d;
    }
  }

  /// Unmounts the app and lets the startup timers (waitAtMost) run out.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('fresh start: no user → background sign-in once → intro → onboarding',
      (tester) async {
    final app = await pumpApp(tester);
    final router = app.router;
    expect(find.byType(SplashScreen), findsOneWidget);

    await advance(tester, const Duration(seconds: 1));
    expect(app.auth.signInCalls, 1);
    expect(app.user, isNotNull);
    expect(app.path, '/');

    // Fonts give up after 3 s (no fetching in tests), the full intro (15 s),
    // then the move to onboarding.
    await advance(tester, const Duration(seconds: 20));
    expect(find.byType(PhilosophyScreen), findsOneWidget);
    expect(app.path, '/onboarding/philosophy');
    expect(identical(app.router, router), isTrue);
    expect(app.auth.signInCalls, 1);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('offline first launch: onboarding without a user; the late sign-in '
      'neither moves the user nor rebuilds the router', (tester) async {
    final app = await pumpApp(tester, holdSignIn: true); // IPv6 black hole
    final router = app.router;
    await advance(tester, const Duration(seconds: 20));
    expect(app.user, isNull);
    expect(app.path, '/onboarding/philosophy');
    expect(find.byType(PhilosophyScreen), findsOneWidget);
    expect(app.auth.signInCalls, 1);

    // Minutes later the sign-in lands.
    app.auth.gate!.complete();
    await advance(tester, const Duration(seconds: 1));
    expect(app.user, isNotNull);
    expect(app.path, '/onboarding/philosophy');
    expect(find.byType(PhilosophyScreen), findsOneWidget);
    expect(identical(app.router, router), isTrue);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('an auth change during the splash keeps the router and the splash',
      (tester) async {
    final app = await pumpApp(tester, holdSignIn: true);
    final router = app.router;
    await tester.pump();
    final splashState = tester.state(find.byType(SplashScreen));

    // Auth state (null), onboarding load, then the sign-in finishing.
    await advance(tester, const Duration(seconds: 1));
    app.auth.gate!.complete();
    await advance(tester, const Duration(seconds: 1));
    expect(app.user, isNotNull);

    expect(identical(app.router, router), isTrue);
    expect(identical(tester.state(find.byType(SplashScreen)), splashState), isTrue);
    expect(app.path, '/');
    expect(tester.takeException(), isNull);

    // Later changes (token refresh / sign-out) never rebuild it either.
    app.auth.emit(_MockUser());
    await tester.pump();
    app.auth.emit(null);
    await tester.pump();
    expect(identical(app.router, router), isTrue);
    expect(identical(tester.state(find.byType(SplashScreen)), splashState), isTrue);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('existing user with onboarding done → short logo → /home',
      (tester) async {
    final app = await pumpApp(tester, user: _MockUser(), onboardingDone: true);
    // Fonts (3 s) + the short logo (1.5 s).
    await advance(tester, const Duration(seconds: 6));
    expect(app.path, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(app.auth.signInCalls, 0);
    expect(tester.takeException(), isNull);
    await finish(tester);
  });

  testWidgets('deep link to /home without a user but onboarding done is allowed',
      (tester) async {
    final app = await pumpApp(tester, onboardingDone: true, holdSignIn: true);
    await tester.pump(); // onboarding state loaded
    app.router.go('/home');
    await tester.pump();
    await tester.pump();
    expect(app.user, isNull);
    expect(app.path, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);
    await finish(tester);
  });

  testWidgets('deep link to /home before onboarding is done → onboarding',
      (tester) async {
    final app = await pumpApp(tester, holdSignIn: true);
    await tester.pump();
    app.router.go('/home');
    await tester.pump();
    await tester.pump();
    expect(app.path, '/onboarding/philosophy');
    expect(find.byType(HomeScreen), findsNothing);
    await finish(tester);
  });

  testWidgets('after account deletion while offline: splash → onboarding',
      (tester) async {
    final app = await pumpApp(tester, user: _MockUser(), onboardingDone: true);
    await advance(tester, const Duration(seconds: 6));
    expect(app.path, '/home');
    final router = app.router;

    // What deleteAccountData does: onboarding reset, Firebase user gone;
    // then the settings screen goes to '/'. No network for the new sign-in.
    app.auth.gate = Completer<void>();
    app.onboarding.set(false);
    app.auth.emit(null);
    await tester.pump();
    router.go('/');
    await advance(tester, const Duration(seconds: 1));
    expect(app.path, '/');
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(app.auth.signInCalls, 1); // background attempt started

    await advance(tester, const Duration(seconds: 20));
    expect(app.user, isNull);
    expect(app.path, '/onboarding/philosophy');
    expect(find.byType(PhilosophyScreen), findsOneWidget);
    expect(identical(app.router, router), isTrue);
    expect(tester.takeException(), isNull);
    app.auth.gate!.complete();
    await finish(tester);
  });

  group('BackgroundSignIn', () {
    test('signs in once at a time and never when a user exists', () async {
      final auth = _FakeAuth()..gate = Completer<void>();
      final bg = BackgroundSignIn(() => auth);
      final run = bg.ensureSignedIn();
      expect(run, isNotNull);
      expect(bg.isRunning, isTrue);
      expect(bg.ensureSignedIn(), isNull); // e.g. a resume while it runs
      expect(auth.signInCalls, 1);

      auth.gate!.complete();
      await run;
      expect(bg.isRunning, isFalse);
      expect(auth.currentUser, isNotNull);
      expect(bg.ensureSignedIn(), isNull); // already signed in
      expect(auth.signInCalls, 1);
      // Not awaited: nobody listens to the stream here, so `done` never comes.
      unawaited(auth.close());
    });

    test('a failing sign-in is swallowed and can be retried (next resume)',
        () async {
      final auth = _FailingAuth();
      final bg = BackgroundSignIn(() => auth);
      await bg.ensureSignedIn();
      expect(bg.isRunning, isFalse);
      await bg.ensureSignedIn();
      expect(auth.calls, 2);
    });

    test('no Firebase (initializeApp failed) → nothing, no throw', () {
      final bg = BackgroundSignIn(() => throw StateError('no Firebase app'));
      expect(bg.ensureSignedIn(), isNull);
    });
  });
}
