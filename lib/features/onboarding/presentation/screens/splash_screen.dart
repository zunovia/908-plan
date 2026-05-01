import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/sound_manager.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/audio_providers.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../onboarding/providers/onboarding_provider.dart';
import '../widgets/intro_rive_animation.dart';

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
    final fontsFuture = AppTypography.preload();

    // Start anonymous auth in background
    try {
      final authService = ref.read(authServiceProvider);
      if (authService.currentUser == null) {
        await authService.signInAnonymously();
      }
    } catch (_) {
      // Auth failure (e.g. no network on first launch) — continue with local-only mode
    }

    bool isOnboardingDone = false;
    try {
      isOnboardingDone = await ref.read(onboardingCompleteProvider.future);
    } catch (_) {
      // Storage read failure — treat as first launch
    }

    // Wait for fonts — failure is non-fatal (falls back to system fonts)
    try {
      await fontsFuture;
    } catch (_) {}

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
