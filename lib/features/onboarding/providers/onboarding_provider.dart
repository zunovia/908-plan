import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/storage_providers.dart';

final onboardingCompleteProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final storage = ref.read(secureStorageProvider);
    return await storage.getOnboardingComplete();
  }

  Future<void> complete() async {
    final storage = ref.read(secureStorageProvider);
    await storage.setOnboardingComplete(true);
    state = const AsyncData(true);
  }
}
