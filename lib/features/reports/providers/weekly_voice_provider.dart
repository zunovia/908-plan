import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/audio_providers.dart';
import '../../../core/providers/storage_providers.dart';

/// Builds the "voice of the week" collage for the current week
/// (Monday to Sunday) from the locally kept clips.
/// Resolves to the WAV path, or null when fewer than two clips exist.
final weeklyVoiceCollageProvider =
    FutureProvider.autoDispose<String?>((ref) async {
  final repo = ref.watch(localRecordingRepositoryProvider);
  final clips = ref.watch(voiceClipServiceProvider);

  final now = DateTime.now();
  final weekStart = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));

  final recordings = repo.getRecordingsInRange(weekStart, weekEnd)
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  if (recordings.length < 2) return null;

  final tempDir = await getTemporaryDirectory();
  return clips.buildCollage(
    recordingIds: recordings.map((r) => r.id).toList(),
    outputPath: '${tempDir.path}/voxna_weekly_voice.wav',
  );
});
