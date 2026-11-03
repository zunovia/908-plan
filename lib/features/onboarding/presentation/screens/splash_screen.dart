import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../onboarding/providers/onboarding_provider.dart';
import '../widgets/intro_rive_animation.dart';

/// Longest the splash waits for each startup step before moving on.
///
/// On networks where IPv6 is black-holed, the font download and the auth call
/// can hang for minutes; the splash must never hang on them. The sign-in is
/// not awaited at all (it runs in the background, see [BackgroundSignIn]);
/// [splashAuthWait] stays the limit for code that does wait for it.
const Duration splashFontsWait = Duration(seconds: 3);
const Duration splashAuthWait = Duration(seconds: 8);
const Duration splashStorageWait = Duration(seconds: 3);

/// Waits for [future] at most [limit]. Errors and timeouts both resolve to
/// null so a slow or failing step never blocks the splash.
Future<T?> waitAtMost<T>(Future<T> future, Duration limit) async {
  try {
    return await future.timeout(limit);
  } catch (_) {
    return null;
  }
}

/// Startup screen: starts the anonymous sign-in in the background, plays the
/// intro, then opens onboarding or home.
///
/// Local-first: nothing waits for the sign-in. The app keeps all data on the
/// device, so it opens the same way offline or when the sign-in takes minutes
/// (IPv6 black hole); the user arrives later through `authStateChanges` and
/// is retried on every app resume (ZeroApp).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _initialized = false;
  bool _isFirstLaunch = true;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startBackgroundSignIn();
    _initialize();
  }

  /// Fire-and-forget; also after an account deletion (no user any more).
  void _startBackgroundSignIn() {
    try {
      ref.read(backgroundSignInProvider).ensureSignedIn();
    } catch (_) {
      // Firebase unavailable: local-only.
    }
  }

  Future<void> _initialize() async {
    // Start font download in parallel with the onboarding check
    // (wrapped right away so an early failure is never an unhandled error).
    final fontsFuture =
        waitAtMost(Future.sync(AppTypography.preload), splashFontsWait);

    // Storage read failure or timeout — treat as first launch.
    final isOnboardingDone = await waitAtMost(
          ref.read(onboardingCompleteProvider.future),
          splashStorageWait,
        ) ??
        false;
    if (!mounted) return;

    // Fonts are optional: if they are not ready in time, system fonts are used
    // and google_fonts swaps them in once the download finishes.
    await fontsFuture;

    if (!mounted) return;
    setState(() {
      _isFirstLaunch = !isOnboardingDone;
      _initialized = true;
    });
    // Navigation is handled by IntroRiveAnimation.onComplete
  }

  void _onIntroComplete() {
    _stopAllSounds();
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(_isFirstLaunch ? '/onboarding/philosophy' : '/home');
  }

  void _onSkip() {
    _stopAllSounds();
  }

  void _onPhaseChanged(int phase) {
    if (!mounted) return;
    final soundManager = ref.read(soundManagerProvider);

    switch (phase) {
      case 1:
        soundManager.play(SoundId.theta, loop: true);
      case 3:
        soundManager.play(SoundId.ambient, loop: true);
    }
  }

  void _stopAllSounds() {
    if (!mounted) return;
    ref.read(soundManagerProvider).stopAll();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const ColoredBox(color: AppColors.darkSurfacePrimary);
    }

    return Scaffold(
      body: IntroRiveAnimation(
        isFirstLaunch: _isFirstLaunch,
        onComplete: _onIntroComplete,
        onSkip: _onSkip,
        onPhaseChanged: _onPhaseChanged,
      ),
    );
  }
}
