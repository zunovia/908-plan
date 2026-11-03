import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/release_repository.dart';
import '../../domain/models.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';

enum _Phase { inhale, hold, exhale }

/// 呼吸のガイド（Luckarise の Breath を移植）。吸う・止める・吐くの秒数は設定（既定 4-4-8）、カードに指定があればそれ。
/// 始めたときにセッションを作り、時間切れか「終える」で保存。1 周もしていなければ残さない。
class BreathScreen extends ConsumerStatefulWidget {
  const BreathScreen({super.key, this.cardId, this.emotion});

  /// 呼吸のカード（breath: [吸, 止, 吐]）。
  final String? cardId;
  final EmotionTag? emotion;

  @override
  ConsumerState<BreathScreen> createState() => _BreathScreenState();
}

class _BreathScreenState extends ConsumerState<BreathScreen> {
  late final ReleaseRepository _repo;
  bool _loading = true;
  int _in = 4;
  int _hold = 4;
  int _out = 8;
  int _minutes = 1;
  bool _running = false;
  bool _started = false;
  _Phase _phase = _Phase.inhale;
  int _phaseRemaining = 4;
  int _totalRemaining = 60;
  int _cycles = 0;
  bool _haptics = true;

  Future<String>? _session;
  Timer? _ticker;
  bool _finalized = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(releaseRepositoryProvider);
    _load();
  }

  Future<void> _load() async {
    final s = ref.read(releaseSettingsProvider);
    var bIn = s.breathIn;
    var bHold = s.breathHold;
    var bOut = s.breathOut;
    final cardId = widget.cardId;
    if (cardId != null) {
      try {
        final domain = await ref.read(releaseDomainProvider.future);
        final card = domain.cardSelector.byId(cardId, ref.read(releaseContentLangProvider));
        final pattern = card?.breath;
        if (pattern != null && pattern.length == 3) {
          bIn = pattern[0];
          bHold = pattern[1];
          bOut = pattern[2];
        }
      } catch (_) {
        // カードが読めなければ設定の秒数で。
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _in = bIn < 1 ? 1 : bIn;
      _hold = bHold < 0 ? 0 : bHold;
      _out = bOut < 1 ? 1 : bOut;
      _phaseRemaining = _in;
      _totalRemaining = _minutes * 60;
      _haptics = s.hapticsEnabled;
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final session = _session;
    if (!_finalized && session != null) {
      final cycles = _cycles;
      final repo = _repo;
      session.then((id) => cycles > 0 ? repo.finishSession(id, cycles) : repo.discardSession(id)).catchError((Object _) {});
    }
    super.dispose();
  }

  int _durationOf(_Phase p) => switch (p) { _Phase.inhale => _in, _Phase.hold => _hold, _Phase.exhale => _out };

  void _setMinutes(int m) {
    if (_started) return;
    setState(() {
      _minutes = m;
      _totalRemaining = m * 60;
    });
  }

  void _start() {
    if (_running) return;
    _session ??= _repo.startSession(kind: SessionKind.BREATH, emotion: widget.emotion, cardId: widget.cardId);
    setState(() {
      _running = true;
      _started = true;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _tick() {
    if (!_running) return;
    var total = _totalRemaining - 1;
    if (total < 0) total = 0;
    if (_phaseRemaining > 1) {
      setState(() {
        _phaseRemaining--;
        _totalRemaining = total;
      });
    } else {
      var next = _phase;
      var cycles = _cycles;
      var duration = 0;
      // 秒数 0 のフェーズ（止めない等）は飛ばす。
      for (var i = 0; i < 3 && duration <= 0; i++) {
        if (next == _Phase.exhale) cycles++;
        next = switch (next) { _Phase.inhale => _Phase.hold, _Phase.hold => _Phase.exhale, _Phase.exhale => _Phase.inhale };
        duration = _durationOf(next);
      }
      if (_haptics) relHaptic();
      setState(() {
        _phase = next;
        _phaseRemaining = duration;
        _totalRemaining = total;
        _cycles = cycles;
      });
    }
    if (total <= 0) _finish();
  }

  Future<void> _finish() async {
    if (_finalized) return;
    _finalized = true;
    _ticker?.cancel();
    if (mounted) setState(() => _running = false);
    final session = _session;
    if (session == null) {
      if (mounted) relBack(context);
      return;
    }
    try {
      final id = await session;
      if (_cycles <= 0) {
        await _repo.discardSession(id);
        if (mounted) relBack(context);
        return;
      }
      await _repo.finishSession(id, _cycles);
      if (mounted) context.go(ReleasePaths.doneFor(id));
    } catch (_) {
      // 保存に失敗しても画面から出られなくならないようにする。
      if (mounted) relBack(context);
    }
  }

  String _phaseLabel(AppLocalizations l10n) => switch (_phase) {
        _Phase.inhale => l10n.rel_breath_phase_in,
        _Phase.hold => l10n.rel_breath_phase_hold,
        _Phase.exhale => l10n.rel_breath_phase_out,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final reduce = relReduceMotion(context);
    final caption = RelStyles.caption.copyWith(color: p.subText);

    const minSize = 120.0;
    const maxSize = 240.0;
    double size;
    if (reduce || !_started) {
      size = reduce ? 160 : minSize;
    } else {
      final d = _durationOf(_phase);
      final f = d > 0 ? (1 - _phaseRemaining / d).clamp(0.0, 1.0) : 1.0;
      size = switch (_phase) {
        _Phase.inhale => minSize + (maxSize - minSize) * f,
        _Phase.hold => maxSize,
        _Phase.exhale => maxSize - (maxSize - minSize) * f,
      };
    }
    final total = _totalRemaining;
    final remaining = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        appBar: RelAppBar(title: l10n.rel_breath_title, onBack: _finish),
        body: _loading
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text(
                        '${l10n.rel_breath_phase_in} $_in ／ ${l10n.rel_breath_phase_hold} $_hold ／ ${l10n.rel_breath_phase_out} $_out',
                        style: caption,
                      ),
                      Expanded(
                        child: Center(
                          child: Semantics(
                            liveRegion: true,
                            label: _started ? '${_phaseLabel(l10n)} $_phaseRemaining' : null,
                            child: AnimatedContainer(
                              duration: reduce ? Duration.zero : const Duration(milliseconds: 900),
                              curve: Curves.easeInOut,
                              width: size,
                              height: size,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: p.ice.withValues(alpha: 0.16)),
                              alignment: Alignment.center,
                              child: ExcludeSemantics(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_started) Text(_phaseLabel(l10n), style: RelStyles.body.copyWith(color: p.text)),
                                    Text('$_phaseRemaining', style: RelStyles.data.copyWith(color: p.text)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(l10n.rel_breath_cycles_label(_cycles), style: RelStyles.body.copyWith(color: p.text)),
                      Text(remaining, style: caption),
                      const SizedBox(height: AppSpacing.md),
                      if (!_started)
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            for (final (m, label) in [
                              (1, l10n.rel_breath_duration_1min),
                              (3, l10n.rel_breath_duration_3min),
                              (5, l10n.rel_breath_duration_5min),
                            ])
                              ChoiceChip(label: Text(label), selected: _minutes == m, onSelected: (_) => _setMinutes(m)),
                          ],
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          if (!_running) ...[
                            Expanded(
                              child: RelPrimaryButton(
                                label: _started ? l10n.rel_breath_resume : l10n.rel_breath_start,
                                onPressed: _start,
                              ),
                            ),
                            if (_started)
                              TextButton(
                                onPressed: _finish,
                                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                                child: Text(l10n.rel_breath_finish),
                              ),
                          ] else ...[
                            TextButton(
                              onPressed: _pause,
                              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                              child: Text(l10n.rel_breath_pause),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: RelPrimaryButton(label: l10n.rel_breath_finish, onPressed: _finish)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
