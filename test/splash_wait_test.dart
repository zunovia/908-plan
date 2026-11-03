import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/onboarding/presentation/screens/splash_screen.dart';

void main() {
  group('waitAtMost', () {
    test('returns the value when the step finishes in time', () async {
      expect(await waitAtMost(Future.value(true), const Duration(seconds: 1)), isTrue);
    });

    test('gives up on a step that never finishes (e.g. IPv6 black hole)', () async {
      final never = Completer<void>().future;
      final sw = Stopwatch()..start();
      await waitAtMost(never, const Duration(milliseconds: 50));
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a failing step resolves to null instead of throwing', () async {
      expect(await waitAtMost<bool>(Future.error(StateError('x')), const Duration(seconds: 1)), isNull);
    });

    test('a step that throws synchronously (via Future.sync) resolves to null', () async {
      expect(
        await waitAtMost<int>(Future.sync(() => throw StateError('x')), const Duration(seconds: 1)),
        isNull,
      );
    });

    test('startup limits stay short', () {
      expect(splashFontsWait, lessThanOrEqualTo(const Duration(seconds: 5)));
      expect(splashStorageWait, lessThanOrEqualTo(const Duration(seconds: 5)));
      expect(splashAuthWait, lessThanOrEqualTo(const Duration(seconds: 10)));
    });
  });
}
