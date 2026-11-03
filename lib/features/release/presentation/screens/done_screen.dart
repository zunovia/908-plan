import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/release_repository.dart';
import '../../domain/weekly_letter.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/mood_picker.dart';
import '../widgets/rel_styles.dart';

/// 完了画面（Luckarise の Done）。「手放しました。」・委ねる一文・今月 N 回目（節目は一言添える）・任意の気分・導線 3 つ。
/// 広告・アプリ内レビュー依頼はなし。
class DoneScreen extends ConsumerStatefulWidget {
  const DoneScreen({super.key, required this.sessionId});

  /// 完了したセッション。
  final String sessionId;

  @override
  ConsumerState<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends ConsumerState<DoneScreen> {
  late final ReleaseRepository _repo;
  String? _surrender;
  int _monthCount = 0;
  bool _milestone = false;
  int? _moodAfter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(releaseRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    final session = _repo.sessionById(widget.sessionId);
    final summary = _repo.summary();
    String? line;
    try {
      final lang = ref.read(releaseContentLangProvider);
      final file = await ref.read(contentRepositoryProvider).surrender(lang);
      final items = file?.items ?? const [];
      final night = _repo.isNight();
      final pool = items.where((i) => i.night == night).toList();
      final use = pool.isEmpty ? items : pool;
      if (use.isNotEmpty) line = use[Random().nextInt(use.length)].text;
    } catch (_) {
      // 一文が無くても完了の表示はできる。
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _surrender = line;
      _monthCount = summary.monthCount;
      _milestone = WeeklyLetter.isMilestone(summary.monthCount);
      _moodAfter = session?.moodAfter;
    });
  }

  void _setMood(int level) {
    final next = _moodAfter == level ? null : level;
    setState(() => _moodAfter = next);
    _repo.setMoodAfter(widget.sessionId, next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(ReleasePaths.home);
      },
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go(ReleasePaths.write),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                        child: Text(l10n.rel_done_one_more),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go(ReleasePaths.home),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                        child: Text(l10n.rel_done_close),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.go('/reports'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.rel_done_see_review),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.rel_done_released,
                    textAlign: TextAlign.center,
                    style: RelStyles.heading.copyWith(color: p.text, fontSize: 22),
                  ),
                  if (_surrender != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(_surrender!, textAlign: TextAlign.center, style: RelStyles.philosophy.copyWith(color: p.text)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (!_loading)
                    Text(
                      _milestone ? l10n.rel_done_milestone(_monthCount) : l10n.rel_done_nth(_monthCount),
                      textAlign: TextAlign.center,
                      style: RelStyles.body.copyWith(color: p.ice, fontSize: 16),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(l10n.rel_done_mood_optional, style: RelStyles.caption.copyWith(color: p.subText)),
                  const SizedBox(height: AppSpacing.xs),
                  MoodPicker(
                    selected: _moodAfter,
                    onSelect: _setMood,
                    semanticLabelFor: l10n.rel_mood_content_description,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
