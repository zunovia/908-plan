import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/core/theme/app_theme.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

// 3:1 is the floor here: it is the app's existing primary/onPrimary pair
// used by every primary button (light theme is about 3.1:1). Raising it to
// the 4.5:1 normal-text level would mean changing the brand colors.
double _contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  for (final entry in {
    'light': ThemeData(colorScheme: AppTheme.lightColorScheme),
    'dark': ThemeData(colorScheme: AppTheme.darkColorScheme),
  }.entries) {
    final theme = entry.value;

    testWidgets('recording stop button (${entry.key}): label colour differs from background and is readable', (tester) async {
      // Same styling as the "recording_done" button in recording_screen.dart.
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.stop),
              label: const Text('done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ));
      final material = tester.widget<Material>(
        find.descendant(of: find.byWidgetPredicate((w) => w is ElevatedButton), matching: find.byType(Material)).first,
      );
      final fg = material.textStyle!.color!;
      final bg = material.color!;
      expect(fg, isNot(equals(bg)));
      expect(_contrast(fg, bg), greaterThanOrEqualTo(3.0));
    });

    test('${entry.key}: onPrimary is readable on primary (FilledButton default)', () {
      final s = theme.colorScheme;
      expect(s.onPrimary, isNot(equals(s.primary)));
      expect(_contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(3.0));
    });
  }
}
