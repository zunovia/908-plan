import 'package:flutter_test/flutter_test.dart';
import 'package:zero_app/features/release/domain/content_models.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/today_pick.dart';
import 'package:zero_app/features/release/domain/weekly_letter.dart';

PracticeMark mark(String day, [List<String> tags = const []]) => PracticeMark(DateTime.parse(day), tags);

void main() {
  // 2026-10-18 は日曜。週の月曜は 10-12。
  final today = DateTime(2026, 10, 18, 15, 30);

  group('WeeklyLetter (Kotlin WeeklyLetterTest)', () {
    test('week starts on Monday', () {
      expect(WeeklyLetter.weekStartOf(today), DateTime(2026, 10, 12));
      expect(WeeklyLetter.weekStartOf(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    });

    test('stats count this week, last week, top tag and rest days', () {
      final marks = [
        mark('2026-10-12', ['仕事']), mark('2026-10-12', ['人']),
        mark('2026-10-13', ['仕事']),
        mark('2026-10-14'),
        mark('2026-10-16', ['仕事', 'これから']),
        mark('2026-10-17'),
        mark('2026-10-18', ['人']),
        mark('2026-10-05'), mark('2026-10-08'), mark('2026-10-11', ['仕事']),
      ];
      final s = WeeklyLetter.stats(marks, today);
      expect(s.thisWeekCount, 7);
      expect(s.lastWeekCount, 3);
      expect(s.topTag, '仕事');
      expect(s.topTagCount, 3);
      expect(s.restDays, [DateTime.thursday]);
      expect(s.weekStart, DateTime(2026, 10, 12));
    });

    test('rest days exclude today and future', () {
      final s = WeeklyLetter.stats([mark('2026-10-12')], today);
      expect(s.restDays, [
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      ]);
      expect(s.topTag, isNull);
      expect(s.topTagCount, 0);
    });

    test('top tag ties go to the smaller key', () {
      final s = WeeklyLetter.stats([mark('2026-10-12', ['b', 'a'])], today);
      expect(s.topTag, 'a');
    });

    test('last7 ends with today', () {
      final d = WeeklyLetter.last7([mark('2026-10-18'), mark('2026-10-12'), mark('2026-10-15')], today);
      expect(d, [true, false, false, true, false, false, true]);
    });

    test('month count only counts this month', () {
      final marks = [mark('2026-09-30'), mark('2026-10-01'), mark('2026-10-18'), mark('2026-11-01')];
      expect(WeeklyLetter.monthCount(marks, today), 2);
    });

    test('welcome back after a gap of three days or more', () {
      expect(WeeklyLetter.isWelcomeBack([mark('2026-10-14'), mark('2026-10-18')], today), isTrue);
      expect(WeeklyLetter.isWelcomeBack([mark('2026-10-16'), mark('2026-10-18')], today), isFalse);
      expect(WeeklyLetter.isWelcomeBack([mark('2026-10-14')], today), isFalse);
      expect(WeeklyLetter.isWelcomeBack([mark('2026-10-18')], today), isFalse);
    });

    test('milestones', () {
      expect(WeeklyLetter.isMilestone(7), isTrue);
      expect(WeeklyLetter.isMilestone(100), isTrue);
      expect(WeeklyLetter.isMilestone(8), isFalse);
    });

    test('week crossing a month and year boundary', () {
      // 2027-01-01 は金曜。週の月曜は 2026-12-28。
      expect(WeeklyLetter.weekStartOf(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
      final s = WeeklyLetter.stats([mark('2026-12-29'), mark('2026-12-21')], DateTime(2027, 1, 1));
      expect(s.thisWeekCount, 1);
      expect(s.lastWeekCount, 1);
    });
  });

  group('TodayPick', () {
    test('today pick is stable per day and cycles', () {
      const items = ['a', 'b', 'c'];
      expect(TodayPick.pick(items, 0), 'a');
      expect(TodayPick.pick(items, 1), 'b');
      expect(TodayPick.pick(items, 3), 'a');
      expect(TodayPick.pick(items, -1), 'c');
      expect(TodayPick.pick(<String>[], 5), isNull);
    });

    test('line uses salt 7', () {
      expect(TodayPick.lineSalt, 7);
      const items = ['a', 'b', 'c'];
      expect(TodayPick.pick(items, 0, salt: TodayPick.lineSalt), 'b'); // (0+7)%3 = 1
    });

    test('epochDay counts days from 1970-01-01 by local date', () {
      expect(TimeRules.epochDay(DateTime(1970, 1, 1, 23, 59)), 0);
      expect(TimeRules.epochDay(DateTime(1970, 1, 2)), 1);
      expect(TimeRules.epochDay(DateTime(1969, 12, 31)), -1);
      expect(TimeRules.dateOfEpochDay(TimeRules.epochDay(DateTime(2026, 11, 3))), DateTime(2026, 11, 3));
    });

    test('card picks the word from custom words or words.json four, and the line with salt', () {
      const words = WordsFile(four: ['a', 'b'], items: [WordItem('a', 'Alpha'), WordItem('b', 'Beta')]);
      const today = TodayFile(items: [TodayItem('T1', 'one'), TodayItem('T2', 'two'), TodayItem('T3', 'three')]);
      final date = DateTime(1970, 1, 2); // epochDay 1
      final c = TodayPick.card(words: words, customWords: const [], today: today, date: date);
      expect(c.word, 'Beta');
      expect(c.line, 'three'); // (1+7)%3 = 2
      final custom = TodayPick.card(words: words, customWords: const ['X'], today: null, date: date);
      expect(custom.word, 'X');
      expect(custom.line, isNull);
    });
  });
}
