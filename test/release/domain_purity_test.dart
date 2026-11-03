import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// domain/ は純 Dart であること（package:flutter・dart:ui を import しない）。Kotlin DomainPurityTest の移植。
void main() {
  test('release domain does not import flutter', () {
    final root = Directory('lib/features/release/domain');
    expect(root.existsSync(), isTrue);
    final violations = <String>[];
    final pattern = RegExp(r'''^\s*(import|export)\s+['"](package:flutter|dart:ui)''');
    for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) violations.add('${f.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('release domain only imports dart:, package:crypto, package:timezone and relative files', () {
    final root = Directory('lib/features/release/domain');
    final allowed = RegExp(r'''^\s*(import|export)\s+['"](dart:(core|math|convert|async|collection)|package:crypto/|package:timezone/|\.|[a-z_]+\.dart)''');
    final importLine = RegExp(r'''^\s*(import|export)\s+['"]''');
    final violations = <String>[];
    for (final f in root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final line in f.readAsLinesSync()) {
        if (importLine.hasMatch(line) && !allowed.hasMatch(line)) violations.add('${f.path}: ${line.trim()}');
      }
    }
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
