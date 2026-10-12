import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../shared/widgets/zero_card.dart';
import '../../providers/weekly_voice_provider.dart';

/// "Voice of the week": plays the first seconds of each recording of the
/// current week, joined together. The audio never leaves the device.
class WeeklyVoiceCard extends ConsumerStatefulWidget {
  const WeeklyVoiceCard({super.key});

  @override
  ConsumerState<WeeklyVoiceCard> createState() => _WeeklyVoiceCardState();
}

class _WeeklyVoiceCardState extends ConsumerState<WeeklyVoiceCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle(String path) async {
    if (_isPlaying) {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    try {
      await _player.play(DeviceFileSource(path));
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final collage = ref.watch(weeklyVoiceCollageProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ZeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.report_weekly_voice_title,
            style: AppTypography.heading.copyWith(
              color: onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          collage.when(
            loading: () => const SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => Text(
              l10n.report_weekly_voice_insufficient,
              style: AppTypography.body.copyWith(color: onSurface),
            ),
            data: (path) {
              if (path == null) {
                return Text(
                  l10n.report_weekly_voice_insufficient,
                  style: AppTypography.body.copyWith(color: onSurface),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.report_weekly_voice_desc,
                    style: AppTypography.body.copyWith(color: onSurface),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _toggle(path),
                      icon: Icon(
                        _isPlaying
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        _isPlaying
                            ? l10n.report_weekly_voice_stop
                            : l10n.report_weekly_voice_play,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
