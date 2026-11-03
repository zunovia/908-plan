import 'dart:ui' show Locale;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zero_app/features/recording/presentation/widgets/mini_insight_card.dart';
import 'package:zero_app/features/release/domain/models.dart';
import 'package:zero_app/features/release/domain/weekly_letter.dart';
import 'package:zero_app/features/reports/presentation/widgets/release_letter_card.dart';
import 'package:zero_app/features/settings/presentation/widgets/release_settings_section.dart';

void main() {
  final ja = lookupAppLocalizations(const Locale('ja'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    await initializeDateFormatting('ja');
    await initializeDateFormatting('en');
  });

  WeeklyStats stats({
    int thisWeek = 5,
    int lastWeek = 3,
    String? topTag = '仕事',
    int topCount = 2,
    List<int> rest = const [],
  }) =>
      WeeklyStats(
        weekStart: DateTime(2026, 11, 2),
        thisWeekCount: thisWeek,
        lastWeekCount: lastWeek,
        topTag: topTag,
        topTagCount: topCount,
        restDays: rest,
      );

  group('composeReleaseLetter', () {
    test('no releases yet → gentle invitation', () {
      expect(composeReleaseLetter(ja, null, 'ja'), ja.rel_review_letter_empty);
      expect(composeReleaseLetter(ja, stats(thisWeek: 0), 'ja'), ja.rel_review_letter_empty);
    });

    test('facts only: count, top chip, difference, rest days', () {
      final text = composeReleaseLetter(
        ja,
        stats(rest: const [DateTime.monday, DateTime.tuesday]),
        'ja',
      );
      expect(
        text,
        '${ja.rel_review_letter_body(5)}'
        '${ja.rel_review_letter_top('仕事', 2)}'
        '${ja.rel_review_letter_more(2)}'
        '${ja.rel_review_letter_rest('月・火')}',
      );
    });

    test('fewer / same / no last week', () {
      expect(composeReleaseLetter(ja, stats(thisWeek: 2, lastWeek: 4, topTag: null), 'ja'),
          '${ja.rel_review_letter_body(2)}${ja.rel_review_letter_fewer(2)}');
      expect(composeReleaseLetter(ja, stats(thisWeek: 3, lastWeek: 3, topTag: null), 'ja'),
          '${ja.rel_review_letter_body(3)}${ja.rel_review_letter_same}');
      expect(composeReleaseLetter(ja, stats(thisWeek: 3, lastWeek: 0, topTag: null), 'ja'),
          ja.rel_review_letter_body(3));
    });

    test('voice tendency chips are shown with their label', () {
      final text = composeReleaseLetter(en, stats(topTag: 'voice:low_energy', lastWeek: 0), 'en');
      expect(text, contains(en.rel_vx_voice_low_energy));
      expect(text, isNot(contains('voice:')));
    });
  });

  test('releaseTagLabel maps voice tags and keeps own chips', () {
    expect(releaseTagLabel(ja, 'voice:steady'), ja.rel_vx_voice_steady);
    expect(releaseTagLabel(ja, 'voice:fast_tempo'), ja.rel_vx_voice_fast_tempo);
    expect(releaseTagLabel(ja, '家族'), '家族');
  });

  group('trigger cue sentence', () {
    test('default follows the first cue, generic without cues', () {
      expect(releaseCueDefaultSentence(ja, const []), ja.rel_settings_trigger_sentence_generic);
      expect(releaseCueDefaultSentence(ja, const [TriggerCue.ON_COMMUTE, TriggerCue.BEFORE_SLEEP]),
          ja.rel_settings_trigger_sentence_on_commute);
    });

    test('an empty or default sentence follows the cues; an own sentence is kept', () {
      expect(
        releaseSentenceAfterCueToggle(
            l10n: ja, before: const [], after: const [TriggerCue.BEFORE_SLEEP], sentence: ''),
        ja.rel_settings_trigger_sentence_before_sleep,
      );
      expect(
        releaseSentenceAfterCueToggle(
          l10n: ja,
          before: const [TriggerCue.BEFORE_SLEEP],
          after: const [],
          sentence: ja.rel_settings_trigger_sentence_before_sleep,
        ),
        '',
      );
      expect(
        releaseSentenceAfterCueToggle(
          l10n: ja,
          before: const [TriggerCue.BEFORE_SLEEP],
          after: const [TriggerCue.BEFORE_SLEEP, TriggerCue.ON_WAKING],
          sentence: '深呼吸してから',
        ),
        isNull,
      );
    });

    test('the own sentence limit matches the repository (60)', () {
      expect(releaseTriggerSentenceMax, 60);
    });
  });

  test('「この声を手放す」 opens the write screen with the recording id', () {
    expect(ReleaseThisVoiceButton.routeFor('1730600000000'), '/release/write?voice=1730600000000');
  });

  test('release l10n keys used by the integration exist in every language', () {
    for (final code in const ['ja', 'en', 'es', 'pt']) {
      final l = lookupAppLocalizations(Locale(code));
      expect(l.rel_vx_settings_section, isNotEmpty);
      expect(l.rel_vx_release_this_voice, isNotEmpty);
      expect(l.rel_vx_weekly_letter_title, isNotEmpty);
      expect(l.rel_vx_calendar_release_count(3), contains('3'));
      expect(l.rel_vx_count_times(2), contains('2'));
      expect(l.rel_vx_notif_channel_name, isNotEmpty);
    }
  });
}
