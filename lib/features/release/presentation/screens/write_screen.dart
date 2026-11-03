import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/records.dart';
import '../../domain/release_tools.dart';
import '../../domain/models.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';

/// 「いま、何が気になる？」（Luckarise の Write を移植）。書くのは任意。記憶チップ・場面チップ・残さない。
/// Voxna 独自: 録音（[voiceRecordingId]）から入ったときは声の傾向を選択済みのチップとして出す。
/// 安全: 本文（と自分で足したチップ）は SafetyGate を通す。危機なら保存せず相談窓口へ。
class WriteScreen extends ConsumerStatefulWidget {
  const WriteScreen({super.key, this.voiceRecordingId, this.sourceSessionId, this.pendingEventId});

  /// 録音（RecordingModel.id）から「この声を手放す」で入った場合。
  final String? voiceRecordingId;

  /// 記録の「もう一度手放す」から入った場合。
  final String? sourceSessionId;

  /// 「あとで手放す」から入った場合。
  final String? pendingEventId;

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _customTag = TextEditingController();

  bool _initialized = false;
  List<String> _tagOptions = const [];
  final List<String> _selectedTags = [];
  final Set<String> _customTags = {};
  List<String> _voiceTags = const [];
  final Set<String> _selectedVoiceTags = {};
  List<String> _sceneOptions = const [];
  String? _selectedScene;
  bool _keep = true;
  bool _fromRecord = false;
  int? _eventAt;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(releaseRepositoryProvider);
    final settings = ref.read(releaseSettingsProvider);
    final source = widget.sourceSessionId == null ? null : repo.releaseAgainDraft(widget.sourceSessionId!);
    final event = widget.pendingEventId == null ? null : repo.pendingEventById(widget.pendingEventId!);
    final frequent = repo
        .topMemoryLabels(6)
        .map((e) => e.label)
        .where((l) => !relIsVoiceTag(l))
        .toList();
    _tagOptions = WriteResult.tagOptions(
      defaultTags: relMemoryDefaults(l10n),
      frequentLabels: frequent,
      sourceTags: source?.tags ?? const [],
    );
    _selectedTags.addAll(source?.tags ?? const []);
    _sceneOptions = relSceneDefaults(l10n);
    final sourceScene = source?.scene;
    if (sourceScene != null && !_sceneOptions.contains(sourceScene)) {
      _sceneOptions = [..._sceneOptions, sourceScene];
    }
    _selectedScene = sourceScene;
    _text.text = source?.note ?? '';
    _keep = settings.keepNotes;
    _fromRecord = source != null;
    _eventAt = event?.occurredAt;
    final voiceId = widget.voiceRecordingId;
    if (voiceId != null) {
      _voiceTags = ref.read(releaseVoiceTagsProvider(voiceId)).where((t) => !_selectedTags.contains(t)).toList();
      _selectedVoiceTags.addAll(_voiceTags);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _customTag.dispose();
    super.dispose();
  }

  bool get _canStart =>
      _text.text.trim().isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _selectedVoiceTags.isNotEmpty ||
      _selectedScene != null;

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) _selectedTags.add(tag);
    });
  }

  void _addCustomTag() {
    var tag = _customTag.text.trim();
    if (tag.length > WriteResult.maxTag) tag = tag.substring(0, WriteResult.maxTag);
    if (tag.isEmpty) return;
    setState(() {
      if (!_tagOptions.contains(tag)) _tagOptions = [tag, ..._tagOptions];
      if (!_selectedTags.contains(tag)) _selectedTags.add(tag);
      _customTags.add(tag);
      _customTag.clear();
    });
  }

  /// 記憶チップ（自分のチップが先、声の傾向は後。先頭が代表チップになる）。
  List<String> get _allTags => [
        ..._selectedTags,
        for (final v in _voiceTags)
          if (_selectedVoiceTags.contains(v)) v,
      ];

  Future<void> _start({required bool empty}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final l10n = AppLocalizations.of(context);
      final text = empty ? '' : _text.text.trim();
      // 自由入力（本文と自分で足したチップ）の安全判定。
      final freeText = [
        if (text.isNotEmpty) text,
        if (!empty)
          for (final t in _customTags)
            if (_selectedTags.contains(t)) t,
      ].join('\n');
      var abuse = false;
      var soft = false;
      if (freeText.isNotEmpty) {
        final dialogue = ref.read(dialogueRepositoryProvider);
        final safety = await dialogue.checkSafety(freeText);
        if (!mounted) return;
        if (safety.isCrisis) {
          await dialogue.recordCrisis();
          if (!mounted) return;
          _text.clear();
          _selectedTags.removeWhere(_customTags.contains);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text(l10n.rel_vx_write_crisis_not_saved)),
          );
          context.go(ReleasePaths.crisisWith(abuse: safety.abuseContext));
          return;
        }
        abuse = safety.abuseContext;
        soft = safety.isSoft;
      }

      if (!mounted) return;
      final tags = empty ? const <String>[] : _allTags;
      final scene = empty ? null : _selectedScene;
      // 「残さない」のときは、自分で打ったチップ（自由入力）も保存しない。既定のチップ・声の傾向だけ残す。
      final storedTags = _keep ? tags : tags.where((t) => !_customTags.contains(t)).toList();
      final result = empty
          ? WriteResult.empty(keep: _keep)
          : WriteResult.from(text: text, tags: storedTags, scene: scene, keep: _keep);
      // 溶ける演出の文字: 本文、無ければチップの表示名。
      final melt = text.isNotEmpty
          ? result.meltText
          : [...tags.map((t) => relTagLabel(l10n, t)), if (scene != null) scene].join(' / ');
      final args = ReleaseSceneArgs(
        mode: ReleaseMode.WORDS4,
        trigger: widget.pendingEventId != null ? SessionTrigger.EVENT : SessionTrigger.MANUAL,
        note: result.note,
        tags: result.tags,
        scene: result.scene,
        keep: result.keep,
        sourceSessionId: widget.sourceSessionId,
        pendingEventId: widget.pendingEventId,
        meltText: (melt == null || melt.isEmpty) ? null : melt,
        voiceRecordingId: widget.voiceRecordingId,
        abuseContext: abuse,
        softCrisis: soft,
      );
      await context.push(ReleasePaths.scene, extra: args);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final freeTextAllowed = ref.watch(releaseFreeTextAllowedProvider).valueOrNull ?? false;
    final label = RelStyles.caption.copyWith(color: p.subText);

    return Scaffold(
      appBar: const RelAppBar(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RelPrimaryButton(
                label: l10n.rel_write_letgo,
                onPressed: (_canStart && !_busy) ? () => _start(empty: false) : null,
              ),
              TextButton(
                onPressed: _busy ? null : () => _start(empty: true),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.rel_write_letgo_empty),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          children: [
            Text(l10n.rel_write_title, style: RelStyles.heading.copyWith(color: p.text)),
            if (_fromRecord) Text(l10n.rel_write_from_record, style: label),
            if (_eventAt != null) Text(l10n.rel_write_from_event(relTimeLabel(_eventAt!, l10n.localeName)), style: label),
            const SizedBox(height: AppSpacing.md),
            if (freeTextAllowed)
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 6,
                maxLength: WriteResult.maxText,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.rel_write_placeholder,
                  border: const OutlineInputBorder(),
                ),
              ),
            if (_voiceTags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.rel_vx_write_from_voice, style: label),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final v in _voiceTags)
                    FilterChip(
                      label: Text(relTagLabel(l10n, v)),
                      selected: _selectedVoiceTags.contains(v),
                      onSelected: (on) => setState(() {
                        if (on) {
                          _selectedVoiceTags.add(v);
                        } else {
                          _selectedVoiceTags.remove(v);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(l10n.rel_write_memory_prompt, style: label),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final t in _tagOptions)
                  FilterChip(
                    label: Text(relTagLabel(l10n, t)),
                    selected: _selectedTags.contains(t),
                    onSelected: (_) => _toggleTag(t),
                  ),
              ],
            ),
            if (freeTextAllowed)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customTag,
                      maxLength: WriteResult.maxTag,
                      maxLines: 1,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _addCustomTag(),
                      decoration: InputDecoration(hintText: l10n.rel_write_custom_tag_placeholder, counterText: ''),
                    ),
                  ),
                  TextButton(
                    onPressed: _customTag.text.trim().isEmpty ? null : _addCustomTag,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(l10n.rel_write_custom_tag_add),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.rel_write_scene_label, style: label),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final s in _sceneOptions)
                  ChoiceChip(
                    label: Text(s),
                    selected: _selectedScene == s,
                    onSelected: (_) => setState(() => _selectedScene = _selectedScene == s ? null : s),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              value: !_keep,
              onChanged: (v) => setState(() => _keep = !(v ?? false)),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l10n.rel_write_no_keep, style: RelStyles.body.copyWith(color: p.text)),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
