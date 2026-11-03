import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../../../release/domain/models.dart';
import '../../../release/domain/release_settings.dart';
import '../../../release/providers/release_providers.dart';
import '../../providers/settings_provider.dart';
import 'setting_tile.dart';

/// Longest "own sentence" (Luckarise: 60 characters; also the repository cap).
const int releaseTriggerSentenceMax = 60;

/// The default release words for the content language (words.json "four").
final _defaultReleaseWordsProvider = FutureProvider<List<String>>((ref) async {
  final lang = ref.watch(releaseContentLangProvider);
  final file = await ref.watch(contentRepositoryProvider).words(lang);
  return file == null ? const [] : file.idsToText(file.four);
});

/// Default "own sentence" for the selected cues (Luckarise CueSentences).
/// The first selected cue decides; with no cue the generic sentence is used.
String releaseCueDefaultSentence(AppLocalizations l10n, List<TriggerCue> cues) {
  if (cues.isEmpty) return l10n.rel_settings_trigger_sentence_generic;
  return switch (cues.first) {
    TriggerCue.BEFORE_SLEEP => l10n.rel_settings_trigger_sentence_before_sleep,
    TriggerCue.ON_WAKING => l10n.rel_settings_trigger_sentence_on_waking,
    TriggerCue.BEFORE_MEETING => l10n.rel_settings_trigger_sentence_before_meeting,
    TriggerCue.BEFORE_CLOSING_SCREEN => l10n.rel_settings_trigger_sentence_before_closing_screen,
    TriggerCue.WHEN_IRRITATED => l10n.rel_settings_trigger_sentence_when_irritated,
    TriggerCue.ON_COMMUTE => l10n.rel_settings_trigger_sentence_on_commute,
  };
}

/// Sentence to store after toggling a cue: when the user's sentence is empty
/// or still the old default, it follows the new cues; otherwise it is kept.
/// Returns null when the sentence should stay as is.
String? releaseSentenceAfterCueToggle({
  required AppLocalizations l10n,
  required List<TriggerCue> before,
  required List<TriggerCue> after,
  required String sentence,
}) {
  final oldDefault = releaseCueDefaultSentence(l10n, before);
  if (sentence.trim().isNotEmpty && sentence != oldDefault) return null;
  return after.isEmpty ? '' : releaseCueDefaultSentence(l10n, after);
}

String _cueLabel(AppLocalizations l10n, TriggerCue cue) => switch (cue) {
      TriggerCue.BEFORE_SLEEP => l10n.rel_settings_trigger_cue_before_sleep,
      TriggerCue.ON_WAKING => l10n.rel_settings_trigger_cue_on_waking,
      TriggerCue.BEFORE_MEETING => l10n.rel_settings_trigger_cue_before_meeting,
      TriggerCue.BEFORE_CLOSING_SCREEN => l10n.rel_settings_trigger_cue_before_closing_screen,
      TriggerCue.WHEN_IRRITATED => l10n.rel_settings_trigger_cue_when_irritated,
      TriggerCue.ON_COMMUTE => l10n.rel_settings_trigger_cue_on_commute,
    };

/// 設定画面の「手放す」節（Luckarise の設定のうち Voxna に入れたもの）。
class ReleaseSettingsSection extends ConsumerStatefulWidget {
  const ReleaseSettingsSection({super.key});

  @override
  ConsumerState<ReleaseSettingsSection> createState() => _ReleaseSettingsSectionState();
}

class _ReleaseSettingsSectionState extends ConsumerState<ReleaseSettingsSection> {
  late final TextEditingController _sentence;

  /// 一文に危機の言葉が入った（保存せず、窓口の入口を出す）。
  bool _sentenceBlocked = false;
  int _sentenceSeq = 0;
  final FocusNode _sentenceFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    var sentence = '';
    try {
      sentence = ref.read(releaseSettingsProvider).triggerSentence;
    } catch (_) {
      // Release storage unavailable; build() hides the section.
    }
    _sentence = TextEditingController(text: sentence);
  }

  @override
  void dispose() {
    _sentence.dispose();
    _sentenceFocus.dispose();
    super.dispose();
  }

  ReleaseSettingsNotifier get _notifier => ref.read(releaseSettingsProvider.notifier);

  Color _sub(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ReleaseSettings s;
    try {
      s = ref.watch(releaseSettingsProvider);
    } catch (_) {
      // Release storage could not be opened: leave the rest of Settings usable.
      return const SizedBox.shrink();
    }

    // Keep the text field in step with changes made elsewhere (cue toggles),
    // without fighting the user while they type.
    ref.listen<String>(releaseSettingsProvider.select((v) => v.triggerSentence), (prev, next) {
      if (!_sentenceFocus.hasFocus && _sentence.text != next) _sentence.text = next;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, l10n.rel_vx_settings_section),
        _triggerCard(context, l10n, s),
        const SizedBox(height: AppSpacing.md),
        _checkinCard(context, l10n, s),
        const SizedBox(height: AppSpacing.md),
        _practiceCard(context, l10n, s),
        const SizedBox(height: AppSpacing.md),
        _moreCard(context, l10n),
      ],
    );
  }

  // ---- 手放すタイミング ----

  Widget _triggerCard(BuildContext context, AppLocalizations l10n, ReleaseSettings s) {
    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, l10n.rel_settings_trigger_title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final cue in TriggerCue.values)
                FilterChip(
                  label: Text(_cueLabel(l10n, cue)),
                  selected: s.triggerCues.contains(cue),
                  onSelected: (_) => _toggleCue(l10n, s, cue),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _sentence,
            focusNode: _sentenceFocus,
            maxLength: releaseTriggerSentenceMax,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: l10n.rel_settings_trigger_sentence_label,
              hintText: releaseCueDefaultSentence(l10n, s.triggerCues),
              isDense: true,
            ),
            onChanged: _onSentenceChanged,
          ),
          if (_sentenceBlocked) ...[
            _note(context, l10n.rel_vx_write_crisis_not_saved),
            TextButton(
              onPressed: () => context.push('/release/crisis'),
              child: Text(l10n.rel_settings_helpline_cta),
            ),
          ],
          _note(context, l10n.rel_settings_trigger_note),
        ],
      ),
    );
  }

  /// 通知のタイトルになる一文にも危機判定を通す。危機なら一文を空にして保存する
  /// （打ちかけの途中までが残らないように）。
  Future<void> _onSentenceChanged(String v) async {
    final seq = ++_sentenceSeq;
    var blocked = false;
    try {
      final check = await ref.read(dialogueRepositoryProvider).checkSafety(v);
      blocked = check.isCrisis || check.abuseContext;
    } catch (_) {
      blocked = false;
    }
    if (!mounted || seq != _sentenceSeq) return;
    if (blocked != _sentenceBlocked) setState(() => _sentenceBlocked = blocked);
    await _notifier.setTriggerSentence(blocked ? '' : v);
  }

  Future<void> _toggleCue(AppLocalizations l10n, ReleaseSettings s, TriggerCue cue) async {
    final before = s.triggerCues;
    final after = before.contains(cue) ? (List.of(before)..remove(cue)) : [...before, cue];
    await _notifier.setTriggerCues(after);
    final sentence = releaseSentenceAfterCueToggle(
      l10n: l10n,
      before: before,
      after: after,
      sentence: s.triggerSentence,
    );
    if (sentence != null) {
      await _notifier.setTriggerSentence(sentence);
      if (!_sentenceFocus.hasFocus) _sentence.text = sentence;
    }
  }

  // ---- 朝夕のチェックイン ----

  Widget _checkinCard(BuildContext context, AppLocalizations l10n, ReleaseSettings s) {
    final now = ref.read(releaseClockProvider)();
    final paused = s.pauseUntil > now;
    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, l10n.rel_settings_checkin_title),
          _reminderRow(
            context,
            label: l10n.rel_settings_checkin_morning,
            enabled: s.checkinMorningEnabled,
            time: s.checkinMorningTime,
            onEnabled: (v) => _notifier.setCheckinMorning(enabled: v),
            onTime: (t) => _notifier.setCheckinMorning(time: t),
          ),
          _reminderRow(
            context,
            label: l10n.rel_settings_checkin_evening,
            enabled: s.checkinEveningEnabled,
            time: s.checkinEveningTime,
            onEnabled: (v) => _notifier.setCheckinEvening(enabled: v),
            onTime: (t) => _notifier.setCheckinEvening(time: t),
          ),
          _reminderRow(
            context,
            label: l10n.rel_settings_checkin_zero,
            enabled: s.zeroDayEnabled,
            time: s.zeroDayTime,
            onEnabled: (v) => _notifier.setZeroDay(enabled: v),
            onTime: (t) => _notifier.setZeroDay(time: t),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.rel_settings_quiet_hours_title, style: _bodyStyle(context)),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: () => _pickTime(context, s.quietStart, '22:00', (t) {
                  _notifier.setQuietHours(t, s.quietEnd);
                }),
                child: Text('${l10n.rel_settings_quiet_hours_start} ${s.quietStart}'),
              ),
              TextButton(
                onPressed: () => _pickTime(context, s.quietEnd, '07:00', (t) {
                  _notifier.setQuietHours(s.quietStart, t);
                }),
                child: Text('${l10n.rel_settings_quiet_hours_end} ${s.quietEnd}'),
              ),
            ],
          ),
          if (paused)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.rel_settings_pause_until(_formatPauseDate(context, s.pauseUntil)),
                    style: _bodyStyle(context),
                  ),
                ),
                TextButton(
                  onPressed: () => _notifier.cancelPause(),
                  child: Text(l10n.rel_settings_pause_cancel),
                ),
              ],
            )
          else
            TextButton(
              onPressed: () => _notifier.pauseOneWeek(),
              child: Text(l10n.rel_settings_pause_week),
            ),
        ],
      ),
    );
  }

  Widget _reminderRow(
    BuildContext context, {
    required String label,
    required bool enabled,
    required String time,
    required Future<void> Function(bool) onEnabled,
    required Future<void> Function(String) onTime,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: _bodyStyle(context))),
        TextButton(
          onPressed: () => _pickTime(context, time, time, (t) => onTime(t)),
          child: Text(time),
        ),
        Switch(
          value: enabled,
          onChanged: (v) async {
            if (v) await _ensurePermission(context);
            await onEnabled(v);
          },
        ),
      ],
    );
  }

  Future<void> _ensurePermission(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final granted = await ref.read(settingsProvider.notifier).requestNotificationPermission();
    if (!granted) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.settings_reminder_permission_denied)));
    }
  }

  Future<void> _pickTime(
    BuildContext context,
    String current,
    String fallback,
    void Function(String) onPicked,
  ) async {
    final parsed = TimeText.parse(current) ?? TimeText.parse(fallback) ?? (hour: 21, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parsed.hour, minute: parsed.minute),
    );
    if (picked == null) return;
    onPicked(TimeText.format(picked.hour, picked.minute));
  }

  String _formatPauseDate(BuildContext context, int epochMillis) {
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.Md(locale).format(DateTime.fromMillisecondsSinceEpoch(epochMillis));
  }

  // ---- 練習 ----

  Widget _practiceCard(BuildContext context, AppLocalizations l10n, ReleaseSettings s) {
    final defaults = ref.watch(_defaultReleaseWordsProvider).valueOrNull ?? const <String>[];
    final words = s.customWords.isEmpty ? defaults : s.customWords;
    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(context, l10n.rel_settings_practice_title),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.rel_settings_words_label, style: _bodyStyle(context)),
                    if (words.isNotEmpty)
                      Text(
                        words.join(' / '),
                        style: AppTypography.caption.copyWith(color: _sub(context)),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _editWords(context, words),
                child: Text(l10n.rel_settings_words_edit),
              ),
            ],
          ),
          _switchRow(context, l10n.rel_settings_keep_notes_label, s.keepNotes, _notifier.setKeepNotes),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.rel_settings_goal_count_label, style: _bodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final n in const [27, 54, 108])
                ChoiceChip(
                  label: Text('$n'),
                  selected: s.goalCount == n,
                  onSelected: (_) => _notifier.setGoalCount(n),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _switchRow(context, l10n.rel_cleaning_tts_label, s.ttsEnabled, _notifier.setTtsEnabled),
          _switchRow(context, l10n.rel_settings_haptics_label, s.hapticsEnabled, _notifier.setHapticsEnabled),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.rel_settings_loop_speed_label, style: _bodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final speed in LoopSpeed.values)
                ChoiceChip(
                  label: Text(switch (speed) {
                    LoopSpeed.OFF => l10n.rel_cleaning_loop_off,
                    LoopSpeed.SLOW => l10n.rel_cleaning_loop_slow,
                    LoopSpeed.NORMAL => l10n.rel_cleaning_loop_normal,
                    LoopSpeed.FAST => l10n.rel_cleaning_loop_fast,
                  }),
                  selected: s.loopSpeedValue == speed,
                  onSelected: (_) => _notifier.setLoopSpeed(speed),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.rel_settings_replay_mode_label, style: _bodyStyle(context)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final mode in ReplayMode.values)
                ChoiceChip(
                  label: Text(switch (mode) {
                    ReplayMode.EVERY => l10n.rel_settings_replay_mode_every,
                    ReplayMode.ONCE_PER_SESSION => l10n.rel_settings_replay_mode_once,
                    ReplayMode.OFF => l10n.rel_cleaning_loop_off,
                  }),
                  selected: s.replayMode == mode,
                  onSelected: (_) => _notifier.setReplayMode(mode),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _switchRow(BuildContext context, String label, bool value, Future<void> Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: _bodyStyle(context))),
        Switch(value: value, onChanged: (v) => onChanged(v)),
      ],
    );
  }

  Future<void> _editWords(BuildContext context, List<String> initial) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: initial.join('\n'));
    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final words = CustomWords.normalize(controller.text.split('\n'));
          return AlertDialog(
            title: Text(l10n.rel_settings_words_dialog_title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    minLines: 4,
                    maxLines: 10,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.rel_settings_words_hint,
                    style: AppTypography.caption.copyWith(color: _sub(dialogContext)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, const <String>[]),
                    child: Text(l10n.rel_settings_words_reset),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.rel_settings_words_cancel),
              ),
              FilledButton(
                onPressed: words.isEmpty ? null : () => Navigator.pop(dialogContext, words),
                child: Text(l10n.rel_settings_words_save),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (result == null) return;
    // 手放す言葉は 27 回唱える言葉になるので、危機の言葉なら保存せず相談窓口へ。
    var blocked = false;
    try {
      final check = await ref.read(dialogueRepositoryProvider).checkSafety(result.join('\n'));
      blocked = check.isCrisis || check.abuseContext;
    } catch (_) {
      blocked = false;
    }
    if (blocked) {
      if (context.mounted) context.push('/release/crisis');
      return;
    }
    await _notifier.setCustomWords(result);
  }

  // ---- 呼吸・相談窓口・説明・クレジット ----

  Widget _moreCard(BuildContext context, AppLocalizations l10n) {
    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingTile(
            title: l10n.rel_breath_title,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/release/breath'),
          ),
          SettingTile(
            title: l10n.rel_settings_helpline_cta,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/release/crisis'),
          ),
          SettingTile(
            title: l10n.rel_vx_settings_show_intro,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/release/intro'),
          ),
          SettingTile(
            title: l10n.rel_settings_credits_title,
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => _showCredits(context),
          ),
          SettingTile(
            title: l10n.rel_settings_delete_all,
            trailing: const Icon(Icons.delete_outline, size: 20),
            onTap: () => _confirmDeleteRecords(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _note(context, l10n.rel_onboarding_p2_disclaimer),
          _note(context, l10n.rel_vx_intro_on_device),
          _note(context, l10n.rel_onboarding_origin_note),
        ],
      ),
    );
  }

  /// 手放した記録・対話の履歴・あとで手放すをすべて消す（設定は残す）。
  Future<void> _confirmDeleteRecords(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rel_settings_delete_all_confirm_title),
        content: Text(l10n.rel_settings_delete_all_confirm_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.rel_settings_delete_all_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.rel_settings_delete_all_confirm_action),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(releaseDbProvider);
    await db.sessions.clear();
    await db.turns.clear();
    await db.pending.clear();
  }

  void _showCredits(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.rel_settings_credits_title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.rel_settings_quote_source_note, style: _bodyStyle(dialogContext)),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.rel_onboarding_origin_note, style: _bodyStyle(dialogContext)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.rel_settings_credits_dialog_close),
          ),
        ],
      ),
    );
  }

  // ---- 見た目 ----

  TextStyle _bodyStyle(BuildContext context) =>
      AppTypography.body.copyWith(color: Theme.of(context).colorScheme.onSurface);

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _cardTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.heading.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(text, style: AppTypography.caption.copyWith(color: _sub(context))),
    );
  }
}
