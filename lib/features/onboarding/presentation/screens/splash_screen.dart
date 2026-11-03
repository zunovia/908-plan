import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../onboarding/providers/onboarding_provider.dart';
import '../widgets/intro_rive_animation.dart';

/// Longest the splash waits for each startup step before moving on.
///
/// On networks where IPv6 is black-holed, the font download and the auth call
/// can hang for minutes; the app must still open (system fonts, local mode).
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

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _initialized = false;
  bool _isFirstLaunch = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Start font download in parallel with auth/onboarding checks
    // (wrapped right away so an early failure is never an unhandled error).
    final fontsFuture = waitAtMost(Future.sync(AppTypography.preload), splashFontsWait);

    // Start anonymous auth in background. Failure or a hung request (e.g. no
    // network on first launch) continues in local-only mode.
    try {
      final authService = ref.read(authServiceProvider);
      if (authService.currentUser == null) {
        await waitAtMost(authService.signInAnonymously(), splashAuthWait);
      }
    } catch (_) {}

    // Storage read failure or timeout — treat as first launch.
    final isOnboardingDone = await waitAtMost(
          ref.read(onboardingCompleteProvider.future),
          splashStorageWait,
        ) ??
        false;

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
    if (mounted) {
      context.go(_isFirstLaunch ? '/onboarding/philosophy' : '/home');
    }
  }

  void _onSkip() {
    _stopAllSounds();
  }

  void _onPhaseChanged(int phase) {
    final soundManager = ref.read(soundManagerProvider);

    switch (phase) {
      case 1:
        soundManager.play(SoundId.theta, loop: true);
      case 3:
        soundManager.play(SoundId.ambient, loop: true);
    }
  }

  void _stopAllSounds() {
    ref.read(soundManagerProvider).stopAll();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const ColoredBox(color: Color(0xFF0A0A0F));
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
