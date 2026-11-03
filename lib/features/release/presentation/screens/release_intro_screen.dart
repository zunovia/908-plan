import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/rel_app_bar.dart';
import '../widgets/rel_styles.dart';

/// 「手放す」の初回説明（考え方の 4 行・由来・医療でない旨・端末内の応答・相談窓口・同意）。
/// Luckarise のオンボーディング 1・2 ページを 1 画面にまとめたもの（年齢確認・AI の説明は Voxna では不要）。
class ReleaseIntroScreen extends ConsumerStatefulWidget {
  const ReleaseIntroScreen({super.key, this.next});

  /// 同意後に開く場所（/release で始まるものだけ。無ければ手放すタブ）。
  final String? next;

  @override
  ConsumerState<ReleaseIntroScreen> createState() => _ReleaseIntroScreenState();
}

class _ReleaseIntroScreenState extends ConsumerState<ReleaseIntroScreen> {
  bool _saving = false;

  String get _next {
    final n = widget.next;
    if (n == null || !n.startsWith(ReleasePaths.home) || n.startsWith(ReleasePaths.intro)) {
      return ReleasePaths.home;
    }
    return n;
  }

  Future<void> _agree() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(releaseSettingsProvider.notifier).acceptDisclaimer();
      if (!mounted) return;
      // 設定から見直しに来た（next なし）なら元の画面へ戻る。門から来たなら行き先へ。
      if (widget.next == null && context.canPop()) {
        context.pop();
      } else {
        context.go(_next);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 戻る: 同意済みの見直しなら元の画面へ。未同意なら手放すタブではなくホームへ。
  void _leave() {
    if (ref.read(releaseSettingsProvider).disclaimerAccepted && context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final lineStyle = RelStyles.philosophy.copyWith(color: p.text, fontSize: 17);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: RelAppBar(title: l10n.rel_vx_intro_title, onBack: _leave),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            children: [
              Text(l10n.rel_onboarding_p1_headline, style: RelStyles.heading.copyWith(color: p.text)),
              const SizedBox(height: AppSpacing.lg),
              for (final line in [
                l10n.rel_onboarding_p1_line1,
                l10n.rel_onboarding_p1_line2,
                l10n.rel_onboarding_p1_line3,
                l10n.rel_onboarding_p1_line4,
              ]) ...[
                Text(line, style: lineStyle),
                const SizedBox(height: AppSpacing.sm + 4),
              ],
              Text(l10n.rel_onboarding_origin_note, style: RelStyles.caption.copyWith(color: p.subText)),
              const SizedBox(height: AppSpacing.lg),
              Divider(color: p.border),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.rel_onboarding_p2_disclaimer, style: RelStyles.body.copyWith(color: p.text)),
              const SizedBox(height: AppSpacing.sm + 4),
              Text(l10n.rel_vx_intro_on_device, style: RelStyles.body.copyWith(color: p.text)),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(ReleasePaths.crisis),
                  icon: const Icon(Icons.call_outlined),
                  label: Text(l10n.rel_vx_intro_helpline_button),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              RelPrimaryButton(label: l10n.rel_vx_intro_agree, onPressed: _saving ? null : _agree),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
