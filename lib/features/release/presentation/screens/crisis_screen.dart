import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../domain/content_models.dart';
import '../../domain/crisis_logic.dart';
import '../../domain/models.dart';
import '../../providers/release_providers.dart';
import '../release_ui.dart';
import '../widgets/rel_styles.dart';

/// 相談窓口を開く先（電話・SMS・Web）。テストで差し替える。
typedef HelplineLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchExternal(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// 窓口番号を電話アプリで開く URI（"#8008" の "#" などはエンコードされる）。
Uri helplineTelUri(String number) => Uri(scheme: 'tel', path: number.replaceAll(' ', ''));

/// SMS の宛先 URI。
Uri helplineSmsUri(String number) => Uri(scheme: 'sms', path: number.replaceAll(' ', ''));

/// 相談窓口（Luckarise の Crisis を移植）。広告・AI・再生リマインドなし。
/// 番号をタップすると電話アプリ（SMS・Web も同様）を開き、開けないときのためにコピーも残す（窓口名は出力ゲートを通さない）。
class CrisisScreen extends ConsumerStatefulWidget {
  const CrisisScreen({super.key, this.abuse = false, this.systemCountry, this.launcher});

  /// 外部アプリを開く関数（テスト用。null なら url_launcher）。
  final HelplineLauncher? launcher;

  /// 虐待・ハラスメントの文脈（ABUSE の窓口を先頭に）。
  final bool abuse;

  /// 端末の国コード（テスト用。null なら PlatformDispatcher のロケール）。
  final String? systemCountry;

  static const String defaultFallbackUrl = 'https://findahelpline.com/';

  @override
  ConsumerState<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends ConsumerState<CrisisScreen> {
  bool _loading = true;
  List<HelplineCountry> _countries = const [];
  String _selected = otherCountryCode;
  String _fallbackUrl = CrisisScreen.defaultFallbackUrl;
  late final AppLang _lang;

  @override
  void initState() {
    super.initState();
    _lang = ref.read(releaseContentLangProvider);
    _load();
  }

  Future<void> _load() async {
    final settingsRepo = ref.read(releaseSettingsRepositoryProvider);
    final now = ref.read(releaseClockProvider)();
    // Luckarise と同じく、窓口を開いた時刻を記録する（手放すタブに 24 時間バナーを出す）。
    settingsRepo.setLastCrisisAt(now).catchError((Object _) => settingsRepo.current);
    Helplines? helplines;
    try {
      helplines = await ref.read(contentRepositoryProvider).helplines();
    } catch (_) {
      helplines = null;
    }
    final countries = helplines?.countries ?? const <HelplineCountry>[];
    final initial = CrisisLogic.resolveInitialCountryCode(
      systemCountry: widget.systemCountry ?? (PlatformDispatcher.instance.locale.countryCode ?? ''),
      appLang: _lang.code,
      availableCodes: countries.map((c) => c.code).toList(),
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _countries = countries;
      _selected = initial;
      final url = helplines?.fallbackUrl ?? '';
      _fallbackUrl = url.trim().isEmpty ? CrisisScreen.defaultFallbackUrl : url;
    });
  }

  List<HelplineEntry> get _lines {
    final c = _countries.where((c) => c.code == _selected).firstOrNull;
    return CrisisLogic.sortedLines(c?.lines ?? const [], abuse: widget.abuse);
  }

  Future<void> _copy(String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final label = AppLocalizations.of(context).rel_crisis_copied;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      return;
    }
    messenger?.showSnackBar(SnackBar(content: Text(label), duration: const Duration(seconds: 2)));
  }

  /// 電話・SMS・Web を開く。開けなければ内容をコピーして知らせる。
  Future<void> _open(Uri uri, String fallbackText) async {
    var opened = false;
    try {
      opened = await (widget.launcher ?? _launchExternal)(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) await _copy(fallbackText);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final lines = _lines;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) relBack(context);
      },
      child: Scaffold(
        backgroundColor: Color.alphaBlend(p.ice.withValues(alpha: 0.06), p.surface),
        body: SafeArea(
          child: _loading
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Text(l10n.rel_crisis_headline, style: RelStyles.heading.copyWith(color: p.text, fontSize: 22)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.rel_crisis_subline, style: RelStyles.body.copyWith(color: p.text)),
                    const SizedBox(height: AppSpacing.md),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _countries)
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: ChoiceChip(
                                label: Text(CrisisLogic.displayLabel(c.code)),
                                selected: _selected == c.code,
                                onSelected: (_) => setState(() => _selected = c.code),
                              ),
                            ),
                          ChoiceChip(
                            label: Text(l10n.rel_crisis_country_other),
                            selected: _selected == otherCountryCode,
                            onSelected: (_) => setState(() => _selected = otherCountryCode),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (lines.isEmpty)
                      Text(l10n.rel_crisis_emergency_note, style: RelStyles.body.copyWith(color: p.text)),
                    for (final line in lines) _HelplineTile(line: line, lang: _lang, onCopy: _copy, onOpen: _open),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.rel_crisis_find_a_helpline, style: RelStyles.caption.copyWith(color: p.subText)),
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            link: true,
                            child: InkWell(
                              onTap: () {
                                final uri = Uri.tryParse(_fallbackUrl);
                                if (uri != null) _open(uri, _fallbackUrl);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                child: Text(
                                  _fallbackUrl,
                                  style: RelStyles.body.copyWith(color: p.ice, decoration: TextDecoration.underline),
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                          icon: const Icon(Icons.copy_outlined),
                          onPressed: () => _copy(_fallbackUrl),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => relBack(context),
                        child: Text(l10n.rel_crisis_back_to_app),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HelplineTile extends StatelessWidget {
  const _HelplineTile({required this.line, required this.lang, required this.onCopy, required this.onOpen});

  final HelplineEntry line;
  final AppLang lang;
  final Future<void> Function(String text) onCopy;
  final Future<void> Function(Uri uri, String fallbackText) onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = RelPalette.of(context);
    final copyLabel = MaterialLocalizations.of(context).copyButtonLabel;
    final sms = line.sms;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.name.forLang(lang), style: RelStyles.body.copyWith(color: p.text, fontSize: 16)),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  line.number,
                  style: RelStyles.heading.copyWith(color: p.text, fontSize: 24),
                ),
              ),
              IconButton(
                tooltip: '${l10n.rel_crisis_call} ${line.number}',
                icon: const Icon(Icons.call_outlined),
                onPressed: () => onOpen(helplineTelUri(line.number), line.number),
              ),
              IconButton(
                tooltip: '$copyLabel ${line.number}',
                icon: const Icon(Icons.copy_outlined),
                onPressed: () => onCopy(line.number),
              ),
            ],
          ),
          Text(line.hours.forLang(lang), style: RelStyles.caption.copyWith(color: p.subText)),
          if (sms != null && sms.trim().isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: SelectableText('${l10n.rel_crisis_text}: $sms', style: RelStyles.body.copyWith(color: p.text)),
                ),
                IconButton(
                  tooltip: '${l10n.rel_crisis_text} $sms',
                  icon: const Icon(Icons.sms_outlined),
                  onPressed: () => onOpen(helplineSmsUri(sms), sms),
                ),
                IconButton(
                  tooltip: '$copyLabel $sms',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => onCopy(sms),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
