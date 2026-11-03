import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/release_repository.dart';
import '../../domain/models.dart';
import '../../domain/release_tools.dart';
import '../../domain/safety_gate.dart';
import '../../domain/tts_lang.dart';
import '../../providers/release_providers.dart';
import '../release_tts.dart';
import '../release_ui.dart';
import '../widgets/chat_bubbles.dart';
import '../widgets/crisis_banner.dart';
import '../widgets/melt_text.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';
import '../widgets/tool_picker.dart';
import '../widgets/word_repeater.dart';

/// 手放しシーン（Luckarise の CleaningScreen / CleaningViewModel を移植）。
/// ①気づく（再生リマインド）→ ②語りかける（自分への 1 行）→ 書いた文字が溶ける → ③唱える（言葉の循環・呼吸の輪・触覚・読み上げ）。
/// セッションは最初のタップで作り、0 回で離れたら残さない。
class ReleaseSceneScreen extends ConsumerStatefulWidget {
  const ReleaseSceneScreen({super.key, this.args = const ReleaseSceneArgs()});

  /// 場面・書いた内容など。
  final ReleaseSceneArgs args;

  /// 目標回数の選択肢。
  static const List<int> goalOptions = [27, 54, 108];

  @override
  ConsumerState<ReleaseSceneScreen> createState() => _ReleaseSceneScreenState();
}

class _ReleaseSceneScreenState extends ConsumerState<ReleaseSceneScreen> {
  static final Random _random = Random();

  late final ReleaseRepository _repo;
  late final ReleaseTts _tts;
  late final AppLang _lang;
  ReleaseWordSet? _wordSet;

  /// 自分のツールの言葉にも危機判定を通す（読み込み済みの辞書で同期判定）。
  SafetyGate? _safetyGate;

  bool _loading = true;
  List<String> _words = const [];
  int _wordIndex = 0;
  int _count = 0;
  int _goal = 27;
  bool _reachedGoal = false;
  String? _childLine;
  String? _replayLine;
  String? _noteLine;
  List<String> _noteLines = const [];
  int _noteIndex = 0;
  LoopSpeed _loopSpeed = LoopSpeed.OFF;
  bool _ttsEnabled = false;
  bool _hapticsEnabled = true;
  List<ToolOption> _tools = const [];
  String _selectedTool = '';
  List<String> _ownTools = const [];
  bool _showOptions = false;
  int _breathIn = 4;
  int _breathHold = 4;
  int _breathOut = 8;

  Future<String>? _session;
  Timer? _loop;
  Timer? _quickTimer;
  bool _finalized = false;
  bool _finishing = false;

  ReleaseSceneArgs get _args => widget.args;
  ReleaseMode get _mode => _args.mode;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(releaseRepositoryProvider);
    _tts = ref.read(releaseTtsProvider);
    _lang = ref.read(releaseContentLangProvider);
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(releaseSettingsProvider);
    try {
      final wordSet = await ref.read(releaseWordSetProvider.future);
      final domain = await ref.read(releaseDomainProvider.future);
      _safetyGate = domain.safetyGate;
      final content = ref.read(contentRepositoryProvider);
      final cardId = _args.cardId;
      final card = cardId == null ? null : domain.cardSelector.byId(cardId, _lang);
      final initial = wordSet.initial(
        _mode,
        savedTool: settings.releaseTool,
        ownTools: settings.ownTools,
        card: card,
      );
      final isNight = _repo.isNight();
      final childItems = (await content.child(_lang))?.items ?? const [];
      final childPool = childItems.where((i) => i.night == isNight).toList();
      final children = childPool.isEmpty ? childItems : childPool;
      final notes = (await content.notes(_lang))?.items.map((n) => n.text).toList() ?? const <String>[];

      String? replay;
      if (settings.replayMode != ReplayMode.OFF && !_args.abuseContext) {
        final replayId = _args.replayId;
        final byId = replayId == null ? null : domain.replayReminder.byId(replayId, _lang);
        replay = (byId ??
                domain.replayReminder.pick(
                  trigger: TriggerKind.UNKNOWN,
                  locale: _lang,
                  isNight: isNight,
                  softCrisis: _args.softCrisis,
                ))
            ?.text;
      }

      if (!mounted) return;
      setState(() {
        _wordSet = wordSet;
        _loading = false;
        _words = initial.words;
        _tools = initial.tools;
        _selectedTool = initial.selectedTool;
        _ownTools = settings.ownTools;
        _goal = _args.quick ? ReleaseWordSet.quickGoal : (card?.repeat ?? settings.goalCount);
        _childLine = children.isEmpty ? null : children[_random.nextInt(children.length)].text;
        _noteLines = notes;
        _noteLine = notes.isEmpty ? null : notes.first;
        _replayLine = replay;
        _loopSpeed = _args.quick ? LoopSpeed.NORMAL : settings.loopSpeedValue;
        _ttsEnabled = settings.ttsEnabled;
        _hapticsEnabled = settings.hapticsEnabled;
        _breathIn = settings.breathIn;
        _breathHold = settings.breathHold;
        _breathOut = settings.breathOut;
      });
      _startLoop(_loopSpeed);
    } catch (_) {
      // コンテンツが読めない場合でも画面は閉じられるようにする。
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _loop?.cancel();
    _quickTimer?.cancel();
    _tts.stop();
    // 「終える」を押さずに離れた（戻る等）場合の保険（Luckarise の onCleared と同じ）。
    final session = _session;
    if (!_finalized && session != null) {
      final count = _count;
      final repo = _repo;
      session.then((id) => count > 0 ? repo.finishSession(id, count) : repo.discardSession(id)).catchError((Object _) {});
    }
    super.dispose();
  }

  String get _currentWord => (_wordIndex < _words.length) ? _words[_wordIndex] : '';

  void _onTap() {
    if (_loading || _words.isEmpty || _finishing) return;
    if (_args.quick && _reachedGoal) return;
    _session ??= _repo.startSession(
      kind: _mode.sessionKind,
      emotion: _args.emotion,
      cardId: _args.cardId,
      trigger: _args.quick ? SessionTrigger.QUICK : _args.trigger,
      note: _args.keep ? _args.note : null,
      tags: _args.tags,
      scene: _args.scene,
      sourceSessionId: _args.sourceSessionId,
      voiceRecordingId: _args.voiceRecordingId,
    );
    final newCount = _count + 1;
    final reachedNow = !_reachedGoal && newCount >= _goal;
    if (_hapticsEnabled) relHaptic(strong: reachedNow);
    if (_ttsEnabled) {
      final word = _currentWord;
      if (word.isNotEmpty) _tts.speak(word, ttsLangFor(word, _lang));
    }
    String? note = _noteLine;
    if (_noteLines.isNotEmpty && newCount % 4 == 0) {
      _noteIndex = (_noteIndex + 1) % _noteLines.length;
      note = _noteLines[_noteIndex];
    }
    setState(() {
      _count = newCount;
      _wordIndex = (_wordIndex + 1) % max(1, _words.length);
      _reachedGoal = _reachedGoal || reachedNow;
      _noteLine = note;
    });
    if (reachedNow && _args.quick) {
      _loop?.cancel();
      // 15 秒のひと言: 目標に届いたら少し待って自動的に完了へ。
      _quickTimer = Timer(const Duration(milliseconds: 900), _finish);
    }
  }

  void _startLoop(LoopSpeed speed) {
    _loop?.cancel();
    final interval = speed.intervalMillis;
    if (interval == null) return;
    _loop = Timer.periodic(Duration(milliseconds: interval), (_) => _onTap());
  }

  void _setLoop(LoopSpeed speed) {
    setState(() => _loopSpeed = speed);
    _startLoop(speed);
  }

  void _setGoal(int goal) => setState(() {
        _goal = goal;
        _reachedGoal = _count >= goal;
      });

  void _setTts(bool enabled) {
    setState(() => _ttsEnabled = enabled);
    ref.read(releaseSettingsProvider.notifier).setTtsEnabled(enabled);
    if (enabled) {
      final word = _currentWord;
      if (word.isNotEmpty) _tts.speak(word, ttsLangFor(word, _lang));
    } else {
      _tts.stop();
    }
  }

  // ---- ツール ----

  void _selectTool(String id) {
    final set = _wordSet;
    if (set == null) return;
    final tool = _tools.where((t) => t.id == id).firstOrNull;
    if (tool == null) return;
    final words = set.wordsForTool(_mode, tool);
    if (words.isEmpty) return;
    setState(() {
      _words = words;
      _wordIndex = 0;
      _selectedTool = tool.id;
    });
    ref.read(releaseSettingsProvider.notifier).setReleaseTool(tool.id);
  }

  /// 自分のツールを足してそのまま使う。空・上限超えなら false。既にあるなら選ぶだけ。
  bool _addOwnTool(String text) {
    final set = _wordSet;
    if (set == null) return false;
    final tool = OwnTools.normalizeOne(text);
    if (tool.isEmpty) return false;
    if (!_ownTools.contains(tool)) {
      if (_ownTools.length >= OwnTools.maxTools) return false;
      _ownTools = [..._ownTools, tool];
      ref.read(releaseSettingsProvider.notifier).setOwnTools(_ownTools);
      setState(() => _tools = set.toolOptions(_mode, _ownTools));
    }
    _selectTool(ReleaseTools.ownId(tool));
    return true;
  }

  /// 自分のツールを消す。使っていたものなら、いつもの言葉の組に戻す。
  ({List<ToolOption> tools, String selected}) _deleteOwnTool(String text) {
    final set = _wordSet;
    if (set == null || !_ownTools.contains(text)) return (tools: _tools, selected: _selectedTool);
    final wasSelected = _selectedTool == ReleaseTools.ownId(text);
    _ownTools = _ownTools.where((t) => t != text).toList();
    ref.read(releaseSettingsProvider.notifier).setOwnTools(_ownTools);
    setState(() => _tools = set.toolOptions(_mode, _ownTools));
    if (wasSelected) _selectTool(ReleaseTools.set);
    return (tools: _tools, selected: _selectedTool);
  }

  Future<void> _openToolPicker() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ToolPickerDialog(
        tools: _tools,
        selectedTool: _selectedTool,
        onSelect: (id) {
          _selectTool(id);
          Navigator.of(dialogContext).pop();
        },
        onDelete: _deleteOwnTool,
        onCreate: () async {
          final full = _tools.where((t) => t.own).length >= OwnTools.maxTools;
          final text = await showDialog<String>(
            context: dialogContext,
            builder: (_) => ToolCreatorDialog(full: full),
          );
          if (text == null) return false;
          final check = _safetyGate?.checkInput(text);
          if (check != null && (check.isCrisis || check.abuseContext)) {
            // 危機の言葉はツールとして保存せず、相談窓口へ（書く画面と同じ扱い）。
            await ref.read(dialogueRepositoryProvider).recordCrisis().catchError((Object _) {});
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            if (mounted) context.push(ReleasePaths.crisisWith(abuse: check.abuseContext));
            return false;
          }
          return _addOwnTool(text);
        },
      ),
    );
  }

  // ---- 終える ----

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _finalized = true;
    _loop?.cancel();
    _quickTimer?.cancel();
    _tts.stop();
    final session = _session;
    if (session == null) {
      if (mounted) relBack(context);
      return;
    }
    try {
      final id = await session;
      if (_count == 0) {
        await _repo.discardSession(id);
        if (mounted) relBack(context);
        return;
      }
      await _repo.finishSession(id, _count);
      final pending = _args.pendingEventId;
      if (pending != null) await _repo.resolvePendingEvent(pending, id);
      if (mounted) context.go(ReleasePaths.doneFor(id));
    } catch (_) {
      // 保存に失敗しても画面から出られなくならないようにする（戻るは _finishing で止まるため）。
      if (mounted) relBack(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final quick = _args.quick;
    final small = RelStyles.caption.copyWith(color: p.subText);
    final melt = _args.meltText;

    final ToolOption? selected = _tools.where((t) => t.id == _selectedTool).firstOrNull;
    final toolLabel = selected == null
        ? l10n.rel_cleaning_tool_choose
        : (selected.id == ReleaseTools.set ? l10n.rel_cleaning_tool_set : selected.text);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: RelAppBar(
          onBack: _finish,
          actions: [
            IconButton(
              tooltip: _ttsEnabled ? l10n.rel_cleaning_sound_off : l10n.rel_cleaning_sound_on,
              icon: Icon(_ttsEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined),
              onPressed: () => _setTts(!_ttsEnabled),
            ),
            if (!quick)
              IconButton(
                tooltip: l10n.rel_release_settings,
                icon: const Icon(Icons.tune),
                onPressed: () => setState(() => _showOptions = !_showOptions),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: RelPrimaryButton(label: l10n.rel_cleaning_end, onPressed: _finish),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  children: [
                    if (_args.softCrisis) ...[
                      CrisisBanner(
                        text: l10n.rel_chat_soft_crisis_banner,
                        actionLabel: l10n.rel_chat_soft_crisis_action,
                        onTap: () => context.push(ReleasePaths.crisis),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (!quick && _tools.isNotEmpty)
                      Center(
                        child: OutlinedButton(
                          onPressed: _openToolPicker,
                          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                          child: Text('${l10n.rel_cleaning_tool_button(toolLabel)} ▾'),
                        ),
                      ),
                    if (_replayLine != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ReplayLine(text: _replayLine!),
                    ],
                    const SizedBox(height: AppSpacing.sm + 4),
                    Text(
                      _childLine ?? l10n.rel_release_self_talk,
                      textAlign: TextAlign.center,
                      style: RelStyles.line.copyWith(color: p.text),
                    ),
                    if (melt != null && melt.trim().isNotEmpty && !quick) ...[
                      const SizedBox(height: AppSpacing.sm),
                      MeltText(text: melt),
                    ],
                    if (quick) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(l10n.rel_release_quick_hint, textAlign: TextAlign.center, style: small),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Semantics(
                        button: true,
                        hint: l10n.rel_release_tap_next,
                        onTap: _onTap,
                        child: WordRepeater(
                          word: _currentWord,
                          count: _count,
                          goal: _goal,
                          currentWordLabel: l10n.rel_cleaning_current_word_label,
                          remainingLabel: l10n.rel_cleaning_remaining_label,
                          breathIn: _breathIn,
                          breathHold: _breathHold,
                          breathOut: _breathOut,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_reachedGoal && !quick)
                      Text(l10n.rel_cleaning_goal_reached, textAlign: TextAlign.center, style: RelStyles.body.copyWith(color: p.ice)),
                    if (!quick) ...[
                      Text(l10n.rel_release_tap_next, textAlign: TextAlign.center, style: small),
                      if (_noteLine != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(_noteLine!, textAlign: TextAlign.center, style: small),
                        ),
                    ],
                    if (_showOptions && !quick) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        children: [
                          for (final g in ReleaseSceneScreen.goalOptions)
                            ChoiceChip(label: Text('$g'), selected: _goal == g, onSelected: (_) => _setGoal(g)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
                        children: [
                          for (final (speed, label) in [
                            (LoopSpeed.OFF, l10n.rel_cleaning_loop_off),
                            (LoopSpeed.SLOW, l10n.rel_cleaning_loop_slow),
                            (LoopSpeed.NORMAL, l10n.rel_cleaning_loop_normal),
                            (LoopSpeed.FAST, l10n.rel_cleaning_loop_fast),
                          ])
                            ChoiceChip(label: Text(label), selected: _loopSpeed == speed, onSelected: (_) => _setLoop(speed)),
                        ],
                      ),
                    ],
                    if (_ttsEnabled)
                      ValueListenableBuilder<bool>(
                        valueListenable: _tts.languageMissing,
                        builder: (context, missing, _) => missing
                            ? Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.md),
                                child: Text(l10n.rel_cleaning_tts_language_missing, textAlign: TextAlign.center, style: small),
                              )
                            : const SizedBox.shrink(),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
      ),
    );
  }
}
